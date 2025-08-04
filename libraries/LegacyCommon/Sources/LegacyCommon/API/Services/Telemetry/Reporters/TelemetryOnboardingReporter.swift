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

import CommonNetworking
import Dependencies
import Ergonomics
import Foundation

class TelemetryOnboardingReporter {
    public typealias Factory = NetworkingFactory & PropertiesManagerFactory & TelemetryAPIFactory & TelemetrySettingsFactory & VpnKeychainFactory

    private let factory: Factory

    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()

    private var telemetryEventScheduler: TelemetryEventScheduler

    init(factory: Factory, telemetryEventScheduler: TelemetryEventScheduler) async {
        self.factory = factory

        self.telemetryEventScheduler = telemetryEventScheduler
    }

    public func onboardingEvent(_ event: OnboardingEvent.Event) async throws {
        guard event != .paymentDone || propertiesManager.isOnboardingInProgress else {
            return
        }
        let cached = try? vpnKeychain.fetchCached()
        let planName = cached?.planName ?? "free"
        @Dependency(\.authKeychain) var authKeychain
        let userIsCredentialLess = authKeychain.fetch(forContext: .mainApp)?.isCredentialLess ?? false

        let event = OnboardingEvent(
            event: event,
            dimensions: .init(
                userCountry: propertiesManager.userLocation?.country ?? "",
                userPlan: planName,
                userTier: CommonTelemetryDimensions.userTier(vpnKeychain: vpnKeychain),
                isCredentiallessEnabled: userIsCredentialLess ? "yes" : "no"
            )
        )
        try await telemetryEventScheduler.report(event: event)
    }
}
