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

import Dependencies

import CommonNetworking
import Connection
import VPNAppCore
import VPNShared

import Domain
import Ergonomics
import Telemetry
import Timer

/// Collects information about connection status updates and upsell.
/// Triggers reporting of the events to Telemetry (if user opted in) and Business endpoint (if business flag is on).
@available(*, deprecated, message: "Use the new connection layer instead")
public class TelemetryLegacyServiceImplementation {
    private let eventNotifier: TelemetryEventNotifier

    private var telemetryUpsellReporter: TelemetryUpsellReporter?
    private var telemetryOnboardingReporter: TelemetryOnboardingReporter?
    private var telemetrySettingsReporter: TelemetrySettingsReporter?
    private var telemetryConnectionStatusReporter: TelemetryLegacyConnectionStatusReporter?
    private var telemetryConversionReporter: TelemetryConversionReporter?

    private var telemetryEventScheduler: TelemetryEventScheduler?
    private var businessEventScheduler: TelemetryEventScheduler?

    public init(
        factory: AppStateManagerFactory,
        eventNotifier: TelemetryEventNotifier = .init()
    ) {
        self.eventNotifier = eventNotifier
        Task {
            await initializeReporters(factory: factory)
        }
    }

    func initializeReporters(factory: AppStateManagerFactory) async {
        let telemetryEventScheduler = await TelemetryEventScheduler(isBusiness: false)
        let businessEventScheduler = await TelemetryEventScheduler(isBusiness: true)

        self.telemetryEventScheduler = telemetryEventScheduler
        self.businessEventScheduler = businessEventScheduler

        telemetryUpsellReporter = await TelemetryUpsellReporter(
            telemetryEventScheduler: telemetryEventScheduler
        )
        telemetryOnboardingReporter = await TelemetryOnboardingReporter(telemetryEventScheduler: telemetryEventScheduler)
        telemetryConnectionStatusReporter = await TelemetryLegacyConnectionStatusReporter(factory: factory, telemetryEventScheduler: telemetryEventScheduler, businessEventScheduler: businessEventScheduler)
        telemetrySettingsReporter = TelemetrySettingsReporter(telemetryEventScheduler: telemetryEventScheduler)

        if #available(iOS 17.4, *) {
            telemetryConversionReporter = TelemetryConversionReporter()
        }
    }

    public func reachabilityChanged(_ networkType: ConnectionDimensions.NetworkType) async {
        await telemetryConnectionStatusReporter?.setNetworkType(networkType)
    }

    public func userInitiatedVPNChange(_ change: UserInitiatedVPNChange) async {
        await telemetryConnectionStatusReporter?.setUserInitiatedVPNChange(change)
    }

    public func onboardingEvent(_ event: OnboardingEvent.Event) async throws {
        telemetryConversionReporter?.onboardingEvent(event)
        try await telemetryOnboardingReporter?.onboardingEvent(event)
    }

    public func startSettingsHeartbeat() {
        telemetrySettingsReporter?.start()
    }

    public func upsellEvent(
        _ event: UpsellEvent.Event,
        modalSource _modalSource: UpsellModalSource?,
        newPlanName: String?,
        offerReference: String?,
        cycle: Int?,
        flowType: UpsellEvent.FlowType?
    ) async throws {
        telemetryConversionReporter?.upsellEvent(event, newPlanName: newPlanName, cycle: cycle)
        try await telemetryUpsellReporter?.upsellEvent(
            event,
            modalSource: _modalSource,
            newPlanName: newPlanName,
            offerReference: offerReference,
            flowType: flowType,
            vpnStatus: telemetryConnectionStatusReporter?.previousConnectionStatus == .connected ? .on : .off
        )
    }

    public func vpnGatewayConnectionChanged(_ connectionStatus: ConnectionStatus) async throws {
        try await telemetryConnectionStatusReporter?.vpnGatewayConnectionChanged(connectionStatus)
    }
}

public extension TelemetryService {
    static var legacyValue: TelemetryService = {
        let implementation = TelemetryLegacyServiceImplementation(factory: Container.sharedContainer)
        return .init(
            onboardingEvent: implementation.onboardingEvent,
            upsellEvent: implementation.upsellEvent,
            startSettingsHeartbeat: implementation.startSettingsHeartbeat,
            vpnGatewayConnectionChanged: implementation.vpnGatewayConnectionChanged,
            connectionStateChanged: unimplemented("This is a part of the new connection layer"),
            userInitiatedVPNChange: implementation.userInitiatedVPNChange,
            reachabilityChanged: implementation.reachabilityChanged
        )
    }()
}
