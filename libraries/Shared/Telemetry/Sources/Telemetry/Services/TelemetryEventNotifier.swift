//
//  Created on 18/01/2023.
//
//  Copyright (c) 2023 Proton AG
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

import CasePaths
import Combine
import Connection
import Dependencies
import Domain
import Foundation
import Network
import NetworkingErgonomics
import ProtonCoreFeatureFlags
import Sharing
import VPNAppCore
import VPNShared

public class TelemetryEventNotifier {
    typealias ModalSource = UpsellModalSource

    @Dependency(\.telemetryService) var telemetryService

    private var cancellables = Set<AnyCancellable>()
    private var pathUpdatesTask: Task<Void, Never>?

    public init() {
        startObserving()
    }

    deinit {
        pathUpdatesTask?.cancel()
    }

    private func startObserving() {
        listenToPathUpdates()

        connectionStatePublisher
            .store(in: &cancellables)

        AppEvent.userInitiatedVPNChange.publisher
            .sink { [weak self] value in
                self?.userInitiatedVPNChange(value)
            }
            .store(in: &cancellables)

        AppEvent.upsellAlertWasDisplayed.publisher
            .compactMap { $0.object as? UpsellModalSource }
            .sink { [weak self] source in
                self?.upsellDisplayed(source)
            }
            .store(in: &cancellables)

        AppEvent.userEngagedWithUpsellAlert.publisher
            .compactMap { $0.object as? UpsellData }
            .sink { [weak self] source in
                self?.upsellEngaged(source)
            }
            .store(in: &cancellables)

        AppEvent.userCompletedUpsellAlertJourney.publisher
            .sink { [weak self] value in
                self?.upsellCompleted(value)
            }
            .store(in: &cancellables)

        AppEvent.userEngagedWithAnnouncement.publisher
            .map { $0.object as? String }
            .sink { [weak self] value in
                self?.announcementEngaged(value)
            }
            .store(in: &cancellables)

        AppEvent.userWasDisplayedAnnouncement.publisher
            .map { $0.object as? String }
            .sink { [weak self] value in
                self?.announcementDisplayed(value)
            }
            .store(in: &cancellables)
    }

    private func listenToPathUpdates() {
        pathUpdatesTask?.cancel()

        pathUpdatesTask = Task {
            @Dependency(\.pathMonitor) var pathMonitor

            await withTaskCancellationHandler {
                let stream = pathMonitor.subscribe()
                pathMonitor.start()
                for await newPath in stream {
                    reachabilityChanged(newPath)
                }
            } onCancel: {
                pathMonitor.stop()
            }
        }
    }

    private var connectionStatePublisher: AnyCancellable {
        @SharedReader(.connectionState) var connectionState

        let publisher = $connectionState.publisher
            .map { state in
                if case .killSwitchActive = state {
                    return ConnectionState.disconnected // For purpose of telemetry killSwitchActive is equivalent to disconnected
                }
                return state
            }
            .filter { // filter out states that are irrelevant to telemetry
                switch $0 {
                case .disconnected, .connected, .connecting: true
                default: false
                }
            }
        return publisher
            .zip(publisher.dropFirst())
            .filter { oldValue, newValue in // only consider transitions to a different state, ignore associated values
                if (newValue.is(\.connected) && !oldValue.is(\.connected))
                    || (newValue.is(\.disconnected) && !oldValue.is(\.disconnected))
                    || (newValue.is(\.connecting) && !oldValue.is(\.connecting)) {
                    true
                } else {
                    false
                }
            }
            .sink { [weak self] oldValue, newValue in
                self?.connectionStateChanged(oldValue: oldValue, newValue: newValue)
            }
    }

    private func reachabilityChanged(_ path: NetworkPath) {
        let networkType: ConnectionDimensions.NetworkType =
            switch path.interfaceType ?? .other {
            case .other, .loopback:
                .other
            case .wifi:
                .wifi
            case .cellular:
                .mobile
            case .wiredEthernet:
                .wired
            @unknown default:
                .other
            }

        Task {
            await telemetryService.reachabilityChanged(networkType)
        }
    }

    private func userInitiatedVPNChange(_ notification: Notification) {
        guard let event = AppEvent(notification.name), event == .userInitiatedVPNChange,
              let change = notification.object as? UserInitiatedVPNChange else {
            return
        }

        Task {
            await telemetryService.userInitiatedVPNChange(change)
        }
    }

    private func vpnGatewayConnectionChanged(_ connectionStatus: ConnectionStatus) {
        Task {
            do {
                try await telemetryService.vpnGatewayConnectionChanged(connectionStatus)
            } catch {
                log.debug("No telemetry event triggered for connection change: \(connectionStatus), error: \(error)", category: .telemetry)
            }
        }
    }

    private func connectionStateChanged(oldValue: ConnectionState, newValue: ConnectionState) {
        Task {
            do {
                try await telemetryService.connectionStateChanged(oldValue, newValue)
            } catch {
                log.debug("No telemetry event triggered for connection change: \(newValue.basicDescription), error: \(error)", category: .telemetry)
            }
        }
    }

    private func upsellDisplayed(_ source: ModalSource?) {
        Task {
            do {
                try await telemetryService
                    .upsellEvent(
                        event: .display,
                        modalSource: source,
                        newPlanName: nil,
                        offerReference: nil,
                        cycle: nil,
                        flowType: nil
                    )
            } catch {
                log.debug("No telemetry event triggered for upsell alert: \(String(describing: source)), error: \(error)", category: .telemetry)
            }
        }
    }

    private func announcementDisplayed(_ offerReference: String?) {
        Task {
            do {
                try await telemetryService
                    .upsellEvent(
                        event: .display,
                        modalSource: .promoOffer,
                        newPlanName: nil,
                        offerReference: offerReference,
                        cycle: nil,
                        flowType: nil
                    )
            } catch {
                log.debug("No telemetry event triggered for announcement offer: \(String(describing: offerReference)), error: \(error)", category: .telemetry)
            }
        }
    }

    private func announcementEngaged(_ offerReference: String?) {
        Task {
            do {
                try await telemetryService
                    .upsellEvent(
                        event: .upgradeAttempt,
                        modalSource: .promoOffer,
                        newPlanName: nil,
                        offerReference: offerReference,
                        cycle: nil,
                        flowType: nil
                    )
            } catch {
                log.debug("No telemetry event triggered for announcement offer: \(String(describing: offerReference)), error: \(error)", category: .telemetry)
            }
        }
    }

    private func upsellEngaged(_ upsellData: UpsellData) {
        Task {
            do {
                try await telemetryService
                    .upsellEvent(
                        event: .upgradeAttempt,
                        modalSource: upsellData.modalSource,
                        newPlanName: upsellData.newPlanName,
                        offerReference: upsellData.reference,
                        cycle: nil,
                        flowType: upsellData.flowType
                    )
            } catch {
                log.debug("No telemetry event triggered for upsell alert: \(String(describing: upsellData.modalSource)), error: \(error)", category: .telemetry)
            }
        }
    }

    private func upsellCompleted(_ notification: Notification) {
        guard let upsellData = notification.object as? UpsellData else {
            log.assertionFailure("Notification object conversion failed in \(#function)", category: .telemetry)
            return
        }
        Task {
            // This will not always schedule an event. Only if the payment is done during the onboarding.
            try? await telemetryService.onboardingEvent(.paymentDone)

            do {
                try await telemetryService
                    .upsellEvent(
                        event: .success,
                        modalSource: upsellData.modalSource,
                        newPlanName: upsellData.newPlanName,
                        offerReference: upsellData.reference,
                        cycle: upsellData.cycle,
                        flowType: upsellData.flowType
                    )
            } catch {
                log.debug("No telemetry event triggered for upsell alert: \(String(describing: upsellData.modalSource)), error: \(error)", category: .telemetry)
            }
        }
    }
}

public struct UpsellData {
    let modalSource: UpsellModalSource?
    let newPlanName: String?
    let reference: String?
    let cycle: Int?
    public let flowType: UpsellEvent.FlowType?

    public static func webIntro(
        modalSource: UpsellModalSource?,
        newPlanName: String?
    ) -> Self {
        Self(
            modalSource: modalSource,
            newPlanName: newPlanName,
            reference: "VPNINTROPRICE2024",
            cycle: 24,
            flowType: .external
        )
    }

    public init(
        modalSource: UpsellModalSource?,
        newPlanName: String?,
        reference: String?,
        cycle: Int?,
        flowType: UpsellEvent.FlowType?
    ) {
        self.modalSource = modalSource
        self.newPlanName = newPlanName
        self.reference = reference
        self.cycle = cycle
        self.flowType = flowType
    }
}
