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

/// A change in the logged-in user's VPN plan tier, derived from `AppEvent.planChanged`.
public struct PlanChange: Equatable, Sendable {
    public let oldTier: VpnTier
    public let newTier: VpnTier

    public init(oldTier: VpnTier, newTier: VpnTier) {
        self.oldTier = oldTier
        self.newTier = newTier
    }
}

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
                .compactMap { $0.object as? VpnDowngradeInfo }
                .map { info in PlanChange(oldTier: info.from.maxTier, newTier: info.to.maxTier) }
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
    if planChange.newTier > planChange.oldTier, planChange.oldTier.isFree {
        netShieldPropertyProvider.setNetShieldType(.level2)
    }
}
