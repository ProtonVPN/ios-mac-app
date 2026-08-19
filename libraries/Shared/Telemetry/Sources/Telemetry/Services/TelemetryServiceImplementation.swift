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

import CommonNetworking
import Connection
import Dependencies
import Domain
import Ergonomics
import Foundation
import Sharing
import VPNAppCore
import VPNShared

final class TelemetryServiceImplementation {
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

    func ratingBoosterPromptRequested() async {
        do {
            try await telemetryEventScheduler?.report(event: ProductPromptsEvent())
        } catch {
            log.debug("\(error)", category: .telemetry)
        }
    }

    func reachabilityChanged(_ networkType: ConnectionDimensions.NetworkType) async {
        _ = await initializeTask.value
        await telemetryConnectionStatusReporter?.setNetworkType(networkType)
    }

    func userInitiatedVPNChange(_ change: UserInitiatedVPNChange) async {
        _ = await initializeTask.value
        await telemetryConnectionStatusReporter?.setUserInitiatedVPNChange(change)
    }

    func onboardingEvent(_ event: OnboardingEvent.Event) async throws {
        _ = await initializeTask.value
        telemetryConversionReporter?.onboardingEvent(event)
        try await telemetryOnboardingReporter?.onboardingEvent(event)
    }

    fileprivate func startListeningForPortChanges() {
        Task {
            @Dependency(\.extensionIPC) var extensionIPC
            for await snapshot in extensionIPC.observeExtensionState() {
                if let port = snapshot.state.port {
                    await telemetryConnectionStatusReporter?.setPort(port)
                }
            }
        }
    }

    fileprivate func startSettingsHeartbeat() {
        Task {
            await telemetrySettingsReporter?.start()
        }
    }

    func upsellEvent(
        _ event: UpsellEvent.Event,
        modalSource _modalSource: UpsellModalSource?,
        newPlanName: String?,
        offerReference: String?,
        cycle: Int?,
        flowType: UpsellEvent.FlowType?
    ) async throws {
        telemetryConversionReporter?.upsellEvent(event, newPlanName: newPlanName, cycle: cycle)
        @SharedReader(.connectionState) var connectionState

        try await telemetryUpsellReporter?.upsellEvent(
            event,
            modalSource: _modalSource,
            newPlanName: newPlanName,
            offerReference: offerReference,
            flowType: flowType,
            vpnStatus: connectionState.is(\.connected) ? .on : .off
        )
    }

    func connectionStateChanged(_ oldValue: Connection.ConnectionState, _ newValue: Connection.ConnectionState) async throws {
        try await telemetryConnectionStatusReporter?.connectionStateChanged(oldValue, newValue)
    }
}

public extension DependencyValues {
    var telemetryService: TelemetryService {
        get { self[TelemetryService.self] }
        set { self[TelemetryService.self] = newValue }
    }
}

/// Important note about the `TestDependencyKey` conformance, do not change this to `DependencyKey`, because
/// Dependencies lib gets upset about accessing the `liveValue` in our `prepareDependencies` call.
extension TelemetryService: TestDependencyKey {
    public static var testValue: TelemetryService {
        .init { _ in
        } upsellEvent: { _, _, _, _, _, _ in
        } connectionStateChanged: { _, _ in
        } userInitiatedVPNChange: { _ in
        } reachabilityChanged: { _ in
        } ratingBoosterPromptRequested: {}
    }

    public static var liveValue: TelemetryService = {
        let implementation = TelemetryServiceImplementation()
        implementation.startSettingsHeartbeat()
        implementation.startListeningForPortChanges()
        return .init(
            onboardingEvent: implementation.onboardingEvent,
            upsellEvent: implementation.upsellEvent,
            connectionStateChanged: implementation.connectionStateChanged,
            userInitiatedVPNChange: implementation.userInitiatedVPNChange,
            reachabilityChanged: implementation.reachabilityChanged,
            ratingBoosterPromptRequested: implementation.ratingBoosterPromptRequested
        )
    }()
}
