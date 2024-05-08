//
//  Created on 13/12/2022.
//
//  Copyright (c) 2022 Proton AG
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
import LocalFeatureFlags
import Ergonomics
import Reachability
import Ergonomics
import VPNShared
import CommonNetworking

public protocol TelemetryServiceFactory {
    func makeTelemetryService() async -> TelemetryService
}

public protocol TelemetrySettingsFactory {
    func makeTelemetrySettings() -> TelemetrySettings
}

public protocol TelemetryService: AnyObject {
    func onboardingEvent(_ event: OnboardingEvent.Event) async throws
    func upsellEvent(
        _ event: UpsellEvent.Event,
        modalSource: UpsellEvent.ModalSource?,
        newPlanName: String?,
        offerReference: String?
    ) async throws

    func vpnGatewayConnectionChanged(_ connectionStatus: ConnectionStatus) async throws
    func userInitiatedVPNChange(_ change: UserInitiatedVPNChange)
    func reachabilityChanged(_ networkType: ConnectionDimensions.NetworkType)
}

extension TelemetryService {
    func upsellEvent(
        _ event: UpsellEvent.Event,
        modalSource: UpsellEvent.ModalSource?,
        newPlanName: String?
    ) async throws {
        try await upsellEvent(event, modalSource: modalSource, newPlanName: newPlanName, offerReference: nil)
    }
}

/// Collects information about connection status updates and upsell.
/// Triggers reporting of the events to Telemetry (if user opted in) and Business endpoint (if business flag is on).
public class TelemetryServiceImplementation: TelemetryService {
    public typealias Factory = NetworkingFactory & AppStateManagerFactory & PropertiesManagerFactory & VpnKeychainFactory & TelemetryAPIFactory & TelemetrySettingsFactory

    private let factory: Factory

    private let eventNotifier: TelemetryEventNotifier

    private var telemetryUpsellReporter: TelemetryUpsellReporter
    private var telemetryOnboardingReporter: TelemetryOnboardingReporter
    private var telemetryConnectionStatusReporter: TelemetryConnectionStatusReporter

    private var telemetryEventScheduler: TelemetryEventScheduler
    private var businessEventScheduler: TelemetryEventScheduler

    init(
        factory: Factory,
        eventNotifier: TelemetryEventNotifier = .init()
    ) async {
        self.factory = factory
        self.eventNotifier = eventNotifier
        
        self.telemetryEventScheduler = await TelemetryEventScheduler(factory: factory, isBusiness: false)
        self.businessEventScheduler = await TelemetryEventScheduler(factory: factory, isBusiness: true)

        self.telemetryUpsellReporter = await TelemetryUpsellReporter(factory: factory,
                                                                     telemetryEventScheduler: telemetryEventScheduler)
        self.telemetryOnboardingReporter = await TelemetryOnboardingReporter(factory: factory, telemetryEventScheduler: telemetryEventScheduler)
        self.telemetryConnectionStatusReporter = await TelemetryConnectionStatusReporter(factory: factory, telemetryEventScheduler: telemetryEventScheduler, businessEventScheduler: businessEventScheduler)

        self.eventNotifier.telemetryService = self
    }

    public func reachabilityChanged(_ networkType: ConnectionDimensions.NetworkType) {
        telemetryConnectionStatusReporter.networkType = networkType
    }

    public func userInitiatedVPNChange(_ change: UserInitiatedVPNChange) {
        telemetryConnectionStatusReporter.userInitiatedVPNChange = change
    }

    public func onboardingEvent(_ event: OnboardingEvent.Event) async throws {
        try await telemetryOnboardingReporter.onboardingEvent(event)
    }

    public func upsellEvent(
        _ event: UpsellEvent.Event,
        modalSource _modalSource: UpsellEvent.ModalSource?,
        newPlanName: String?,
        offerReference: String? = nil
    ) async throws {
        try await telemetryUpsellReporter.upsellEvent(
            event,
            modalSource: _modalSource,
            newPlanName: newPlanName,
            offerReference: offerReference,
            vpnStatus: telemetryConnectionStatusReporter.previousConnectionStatus == .connected ? .on : .off)
    }

    public func vpnGatewayConnectionChanged(_ connectionStatus: ConnectionStatus) async throws {
        try await telemetryConnectionStatusReporter.vpnGatewayConnectionChanged(connectionStatus)
    }
}
