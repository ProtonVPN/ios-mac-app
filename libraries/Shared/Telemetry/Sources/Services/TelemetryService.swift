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
import Timer

public protocol TelemetryService: AnyObject {
    func onboardingEvent(_ event: OnboardingEvent.Event) async throws
    func upsellEvent(
        _ event: UpsellEvent.Event,
        modalSource: UpsellModalSource?,
        newPlanName: String?,
        offerReference: String?,
        flowType: UpsellEvent.FlowType?
    ) async throws
    func startSettingsHeartbeat()

//    func vpnGatewayConnectionChanged(_ connectionStatus: ConnectionStatus) async throws
    func connectionStateChanged(_ connectionState: ConnectionState) async throws
    func userInitiatedVPNChange(_ change: UserInitiatedVPNChange) async
    func reachabilityChanged(_ networkType: ConnectionDimensions.NetworkType) async
}

/// Collects information about connection status updates and upsell.
/// Triggers reporting of the events to Telemetry (if user opted in) and Business endpoint (if business flag is on).
public class TelemetryServiceImplementation: TelemetryService {
    private let eventNotifier: TelemetryEventNotifier

    private var telemetryUpsellReporter: TelemetryUpsellReporter?
    private var telemetryOnboardingReporter: TelemetryOnboardingReporter?
    private var telemetrySettingsReporter: TelemetrySettingsReporter?
    private var telemetryConnectionStatusReporter: TelemetryConnectionStatusReporter?

    private var telemetryEventScheduler: TelemetryEventScheduler?
    private var businessEventScheduler: TelemetryEventScheduler?

    init(
        eventNotifier: TelemetryEventNotifier = .init()
    ) {
        self.eventNotifier = eventNotifier
        self.eventNotifier.telemetryService = self
        Task {
            await initializeReporters()
        }
    }

    func initializeReporters() async {
        let telemetryEventScheduler = await TelemetryEventScheduler(isBusiness: false)
        let businessEventScheduler = await TelemetryEventScheduler(isBusiness: true)

        self.telemetryEventScheduler = telemetryEventScheduler
        self.businessEventScheduler = businessEventScheduler

        telemetryUpsellReporter = await TelemetryUpsellReporter(telemetryEventScheduler: telemetryEventScheduler)
        telemetryOnboardingReporter = await TelemetryOnboardingReporter(telemetryEventScheduler: telemetryEventScheduler)
        telemetryConnectionStatusReporter = await TelemetryConnectionStatusReporter(
            telemetryEventScheduler: telemetryEventScheduler,
            businessEventScheduler: businessEventScheduler
        )
        telemetrySettingsReporter = TelemetrySettingsReporter(telemetryEventScheduler: telemetryEventScheduler)
    }

    public func reachabilityChanged(_ networkType: ConnectionDimensions.NetworkType) async {
        await telemetryConnectionStatusReporter?.setNetworkType(networkType)
    }

    public func userInitiatedVPNChange(_ change: UserInitiatedVPNChange) async {
        await telemetryConnectionStatusReporter?.setUserInitiatedVPNChange(change)
    }

    public func onboardingEvent(_ event: OnboardingEvent.Event) async throws {
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
        flowType: UpsellEvent.FlowType?
    ) async throws {
        try await telemetryUpsellReporter?.upsellEvent(
            event,
            modalSource: _modalSource,
            newPlanName: newPlanName,
            offerReference: offerReference,
            flowType: flowType,
            vpnStatus: telemetryConnectionStatusReporter?.previousConnectionStatus == .connected ? .on : .off
        )
    }

    public func connectionStateChanged(_ connectionState: Connection.ConnectionState) async throws {
        try await
            telemetryConnectionStatusReporter?
            .connectionStateChanged(connectionState)
    }
}

public extension DependencyValues {
    var telemetryService: TelemetryService {
        get { self[TelemetryServiceKey.self] }
        set { self[TelemetryServiceKey.self] = newValue }
    }
}

public struct TelemetryServiceKey: DependencyKey {
    public static var liveValue: TelemetryService = TelemetryServiceImplementation()

    #if DEBUG
//        public static let testValue: Container = placeholder
    #endif
}
