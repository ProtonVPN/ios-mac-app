//
//  Created on 15/06/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Domain
import Foundation
import Sharing
import VPNShared

/// A change in the logged-in user's VPN plan, derived from `AppEvent.planChanged`.
public struct PlanChange: Equatable, Sendable {
    public let oldTier: VpnTier
    public let newTier: VpnTier
    /// The plan the user moved to, when the API named it. The welcome screen and the upsell telemetry report it.
    public let newPlanName: String?

    /// Whether the user moved up a tier, which is what makes a change worth welcoming and reporting.
    public var isUpgrade: Bool {
        oldTier < newTier
    }

    public init(oldTier: VpnTier, newTier: VpnTier, newPlanName: String? = nil) {
        self.oldTier = oldTier
        self.newTier = newTier
        self.newPlanName = newPlanName
    }

    /// The pair of credentials the keychain swapped, reduced to the plan change they stand for.
    public init(_ info: VpnDowngradeInfo) {
        self.init(oldTier: info.from.maxTier, newTier: info.to.maxTier, newPlanName: info.to.planName)
    }
}

/// Every plan change the app reacts to, read from here rather than from `AppEvent.planChanged` directly, so each
/// reader gets a typed payload and can be handed a stream it controls in tests.
public struct PlanChangeClient: Sendable {
    public var events: @Sendable () -> AsyncStream<PlanChange>

    public init(events: @escaping @Sendable () -> AsyncStream<PlanChange>) {
        self.events = events
    }
}

extension PlanChangeClient: DependencyKey {
    public static let liveValue = PlanChangeClient(events: {
        UncheckedSendable(
            NotificationCenter.default
                .notifications(named: AppEvent.planChanged.name)
                .compactMap { notification -> PlanChange? in
                    // Everything that posts this event sends the credentials it swapped. A post without them says
                    // that something changed but not what, which no reader can act on.
                    guard let info = notification.object as? VpnDowngradeInfo else {
                        log.error("A plan change arrived without the credentials it changed between", category: .app)
                        return nil
                    }
                    return PlanChange(info)
                }
        )
        .eraseToStream()
    })

    public static let testValue = PlanChangeClient { AsyncStream { $0.finish() } }
}

public extension DependencyValues {
    var planChangeClient: PlanChangeClient {
        get { self[PlanChangeClient.self] }
        set { self[PlanChangeClient.self] = newValue }
    }
}

public func applyPlanChangeFeatureResets(_ planChange: PlanChange) {
    @Dependency(\.natTypePropertyProvider) var natTypePropertyProvider
    @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider
    @Dependency(\.portForwardingPropertyProvider) var portForwardingPropertyProvider

    // Downgrade to free: turn the paid features off / back to default, and disable Secure Core
    if planChange.newTier.isFree {
        natTypePropertyProvider.setNATType(.default)
        netShieldPropertyProvider.setNetShieldType(.off)
        portForwardingPropertyProvider.setPortForwarding(false)

        @Shared(.secureCoreToggle) var secureCoreToggle
        $secureCoreToggle.withLock { $0 = false }
    }

    // Upgrade from free: switch NetShield to the default value for the new tier.
    if planChange.isUpgrade, planChange.oldTier.isFree {
        netShieldPropertyProvider.setNetShieldType(.level2)
    }
}
