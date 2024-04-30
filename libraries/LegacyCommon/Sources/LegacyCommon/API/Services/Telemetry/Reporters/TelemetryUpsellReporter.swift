//
//  Created on 23/01/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Ergonomics
import CommonNetworking

class TelemetryUpsellReporter {

    public typealias Factory = PropertiesManagerFactory & NetworkingFactory & TelemetryAPIFactory & TelemetrySettingsFactory & VpnKeychainFactory

    private let factory: Factory

    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()

    /// The last modal that drove an upsell event.
    @ExpiringValue(timeout: .minutes(10))
    var previousModalSource: UpsellEvent.ModalSource?
    /// The last notification interaction's offer reference name, if defined, that drove an upsell event.
    @ExpiringValue(timeout: .minutes(10))
    var previousOfferReference: String?

    private var telemetryEventScheduler: TelemetryEventScheduler

    init(factory: Factory, telemetryEventScheduler: TelemetryEventScheduler) async {
        self.factory = factory
        self.telemetryEventScheduler = telemetryEventScheduler
    }

    func upsellEvent(_ event: UpsellEvent.Event,
                     modalSource _modalSource: UpsellEvent.ModalSource?,
                     newPlanName: String?,
                     offerReference: String?,
                     vpnStatus: UpsellEvent.VPNStatus) async throws {
        let modalSource: UpsellEvent.ModalSource?
        #if os(macOS)
        // macOS payments happen through the web, so on success collapse it with the previous value if it's missing.
        if event == .success {
            modalSource = _modalSource ?? previousModalSource
        } else {
            modalSource = _modalSource
        }
        #else
        modalSource = _modalSource
        #endif

        guard let modalSource else {
            throw "unable to determine modal source, ignoring event"
        }

        previousModalSource = modalSource
        if let offerReference {
            previousOfferReference = offerReference
        }

        guard let accountCreationDate = propertiesManager.userAccountCreationDate else {
            throw "user account creation date is nil, ignoring event: \(modalSource)"
        }

        let cached = try? vpnKeychain.fetchCached()
        let planName = cached?.planName ?? "free"

        let daysSinceAccountCreation = Date().timeIntervalSince(accountCreationDate) / .days(1)

        let event = UpsellEvent(
            event: event,
            dimensions: .init(
                modalSource: modalSource,
                userPlan: planName,
                vpnStatus: vpnStatus,
                userCountry: propertiesManager.userLocation?.country ?? "",
                newFreePlanUi: propertiesManager.featureFlags.showNewFreePlan,
                daysSinceAccountCreation: Int(daysSinceAccountCreation),
                upgradedUserPlan: newPlanName,
                reference: offerReference
            )
        )
        try await telemetryEventScheduler.report(event: event)
    }
}

#if DEBUG
extension TelemetryUpsellReporter {
    func setValueTimeout(_ timeout: TimeInterval?) {
        _previousModalSource.timeout = timeout
        _previousOfferReference.timeout = timeout
    }
}
#endif
