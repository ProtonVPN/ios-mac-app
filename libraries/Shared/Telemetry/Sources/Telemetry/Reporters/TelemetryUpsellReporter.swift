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

import Dependencies
import Sharing

import CommonNetworking
import Ergonomics
import VPNAppCore

public final class TelemetryUpsellReporter {
    struct Error: Swift.Error {
        let localizedDescription: String
    }

    @Dependency(\.vpnKeychain) private var vpnKeychain
    @SharedReader(.userCountry) var userCountry
    @SharedReader(.userAccountCreationDate) var userAccountCreationDate

    /// The last modal that drove an upsell event.
    @ExpiringValue(timeout: .minutes(10))
    var previousModalSource: UpsellModalSource?
    /// The last notification interaction's offer reference name, if defined, that drove an upsell event.
    @ExpiringValue(timeout: .minutes(10))
    var previousOfferReference: String?

    private var telemetryEventScheduler: TelemetryEventScheduler

    public init(telemetryEventScheduler: TelemetryEventScheduler) async {
        self.telemetryEventScheduler = telemetryEventScheduler
    }

    public func upsellEvent(
        _ event: UpsellEvent.Event,
        modalSource _modalSource: UpsellModalSource?,
        newPlanName: String?,
        offerReference: String?,
        flowType: UpsellEvent.FlowType?,
        vpnStatus: UpsellEvent.VPNStatus
    ) async throws {
        let modalSource: UpsellModalSource?
            // macOS and some iOS payments happen through the web, so on success collapse it with the previous value if it's missing.
            = if event == .success {
            _modalSource ?? previousModalSource
        } else {
            _modalSource
        }

        guard let modalSource else {
            throw Error(localizedDescription: "unable to determine modal source, ignoring event")
        }

        previousModalSource = modalSource
        if let offerReference {
            previousOfferReference = offerReference
        }

        guard let userAccountCreationDate else {
            throw Error(localizedDescription: "user account creation date is nil, ignoring event: \(modalSource)")
        }

        let cached = try? vpnKeychain.fetchCached()
        let planName = cached?.planName ?? "free"

        let daysSinceAccountCreation = Date().timeIntervalSince(userAccountCreationDate) / .days(1)

        @Dependency(\.credentiallessHelper) var credentiallessHelper
        let userIsCredentialLess = credentiallessHelper.isCredentialLess()

        let event = UpsellEvent(
            event: event,
            dimensions: .init(
                modalSource: modalSource,
                userPlan: planName,
                userTier: CommonTelemetryDimensions.userTier(),
                vpnStatus: vpnStatus,
                userCountry: userCountry ?? "",
                daysSinceAccountCreation: Int(daysSinceAccountCreation),
                upgradedUserPlan: newPlanName,
                reference: offerReference,
                flowType: flowType,
                isCredentiallessEnabled: userIsCredentialLess ? "yes" : "no"
            )
        )
        try await telemetryEventScheduler.report(event: event)
    }
}

#if DEBUG
    extension TelemetryUpsellReporter {
        func _expireTimeouts() {
            _previousModalSource.timeout = 0
            _previousOfferReference.timeout = 0
        }
    }
#endif
