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

public final class TelemetryServiceImplementation {
    private let eventNotifier: TelemetryEventNotifier

    private var telemetryUpsellReporter: TelemetryUpsellReporter?
    private var telemetryOnboardingReporter: TelemetryOnboardingReporter?
    private var telemetrySettingsReporter: TelemetrySettingsReporter?
    private var telemetryConnectionStatusReporter: TelemetryConnectionStatusReporter?
    private var telemetryConversionReporter: TelemetryConversionReporter?

    private var telemetryEventScheduler: TelemetryEventScheduler?
    private var businessEventScheduler: TelemetryEventScheduler?

    private var initializeTask: Task<Void, Never>!

    init(
        eventNotifier: TelemetryEventNotifier = .init()
    ) {
        self.eventNotifier = eventNotifier
        self.initializeTask = Task {
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

        #if canImport(AdAttributionKit)
            if #available(iOS 17.4, *) {
                telemetryConversionReporter = TelemetryConversionReporter()
            }
        #endif
    }

    public func reachabilityChanged(_ networkType: ConnectionDimensions.NetworkType) async {
        _ = await initializeTask.value
        await telemetryConnectionStatusReporter?.setNetworkType(networkType)
    }

    public func userInitiatedVPNChange(_ change: UserInitiatedVPNChange) async {
        _ = await initializeTask.value
        await telemetryConnectionStatusReporter?.setUserInitiatedVPNChange(change)
    }

    public func onboardingEvent(_ event: OnboardingEvent.Event) async throws {
        _ = await initializeTask.value
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

    public func connectionStateChanged(_ connectionState: Connection.ConnectionState) async throws {
        try await telemetryConnectionStatusReporter?.connectionStateChanged(connectionState)
    }
}

public extension DependencyValues {
    var telemetryService: TelemetryService {
        get { self[TelemetryService.self] }
        set { self[TelemetryService.self] = newValue }
    }
}

extension TelemetryService: DependencyKey {
    public static var liveValue: TelemetryService = {
        let implementation = TelemetryServiceImplementation()
        return .init(
            onboardingEvent: implementation.onboardingEvent,
            upsellEvent: implementation.upsellEvent,
            startSettingsHeartbeat: implementation.startSettingsHeartbeat,
            vpnGatewayConnectionChanged: unimplemented("This is a part of the old connection layer"),
            connectionStateChanged: implementation.connectionStateChanged,
            userInitiatedVPNChange: implementation.userInitiatedVPNChange,
            reachabilityChanged: implementation.reachabilityChanged
        )
    }()
}
