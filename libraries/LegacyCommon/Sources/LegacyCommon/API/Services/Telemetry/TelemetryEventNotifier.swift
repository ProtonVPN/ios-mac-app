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

import Combine
import ComposableArchitecture
import Connection
import Domain
import Foundation
import ProtonCoreFeatureFlags
import Reachability
import VPNAppCore

public class TelemetryEventNotifier {
    typealias ModalSource = UpsellModalSource

    weak var telemetryService: TelemetryService?

    private var cancellables = Set<AnyCancellable>()

    init() {
        startObserving()
    }

    private func startObserving() {
        @SharedReader(.connectionState) var connectionState: ConnectionState

        NotificationCenter.default
            .publisher(for: .reachabilityChanged)
            .sink { [weak self] notification in
                self?.reachabilityChanged(notification)
            }
            .store(in: &cancellables)

        if FeatureFlagsRepository.isConnectionFeatureEnabled {
            $connectionState.publisher
                .removeDuplicates()
                .sink { [weak self] state in
                    self?.connectionStateChanged(state)
                }
                .store(in: &cancellables)
        } else {
            AppEvent.connectionStateChanged.publisher
                .compactMap { $0.object as? ConnectionStatus }
                .removeDuplicates()
                .sink { [weak self] status in
                    self?.vpnGatewayConnectionChanged(status)
                }
                .store(in: &cancellables)
        }

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

    private func reachabilityChanged(_ notification: Notification) {
        guard notification.name == .reachabilityChanged,
              let reachability = notification.object as? Reachability else {
            return
        }
        let networkType: ConnectionDimensions.NetworkType = switch reachability.connection {
        case .unavailable, .none:
            .other
        case .wifi:
            .wifi
        case .cellular:
            .mobile
        }
        telemetryService?.reachabilityChanged(networkType)
    }

    private func userInitiatedVPNChange(_ notification: Notification) {
        guard let event = AppEvent(notification.name), event == .userInitiatedVPNChange,
              let change = notification.object as? UserInitiatedVPNChange else {
            return
        }
        telemetryService?.userInitiatedVPNChange(change)
    }

    private func vpnGatewayConnectionChanged(_ connectionStatus: ConnectionStatus) {
        Task {
            do {
                try await telemetryService?.vpnGatewayConnectionChanged(connectionStatus)
            } catch {
                log.debug("No telemetry event triggered for connection change: \(connectionStatus), error: \(error)", category: .telemetry)
            }
        }
    }

    private func connectionStateChanged(_ connectionState: ConnectionState) {
        Task {
            do {
                try await telemetryService?.connectionStateChanged(connectionState)
            } catch {
                log.debug("No telemetry event triggered for connection change: \(connectionState), error: \(error)", category: .telemetry)
            }
        }
    }

    private func upsellDisplayed(_ source: ModalSource?) {
        Task {
            do {
                try await telemetryService?
                    .upsellEvent(.display, modalSource: source, newPlanName: nil, offerReference: nil, flowType: nil)
            } catch {
                log.debug("No telemetry event triggered for upsell alert: \(String(describing: source)), error: \(error)", category: .telemetry)
            }
        }
    }

    private func announcementDisplayed(_ offerReference: String?) {
        Task {
            do {
                try await telemetryService?
                    .upsellEvent(
                        .display,
                        modalSource: .promoOffer,
                        newPlanName: nil,
                        offerReference: offerReference,
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
                try await telemetryService?
                    .upsellEvent(
                        .upgradeAttempt,
                        modalSource: .promoOffer,
                        newPlanName: nil,
                        offerReference: offerReference,
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
                try await telemetryService?
                    .upsellEvent(
                        .upgradeAttempt,
                        modalSource: upsellData.modalSource,
                        newPlanName: upsellData.newPlanName,
                        offerReference: upsellData.reference,
                        flowType: upsellData.flowType
                    )
            } catch {
                log.debug("No telemetry event triggered for upsell alert: \(String(describing: upsellData.modalSource)), error: \(error)", category: .telemetry)
            }
        }
    }

    private func upsellCompleted(_ notification: Notification) {
        guard let upsellData = notification.object as? UpsellData else {
            log.assertionFailure("Notification object conversion failed in \(#function)")
            return
        }
        Task {
            // This will not always schedule an event. Only if the payment is done during the onboarding.
            try? await telemetryService?.onboardingEvent(.paymentDone)

            do {
                try await telemetryService?
                    .upsellEvent(
                        .success,
                        modalSource: upsellData.modalSource,
                        newPlanName: upsellData.newPlanName,
                        offerReference: upsellData.reference,
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
    public let flowType: UpsellEvent.FlowType?

    public init(
        modalSource: UpsellModalSource?,
        newPlanName: String?,
        reference: String?,
        flowType: UpsellEvent.FlowType?
    ) {
        self.modalSource = modalSource
        self.newPlanName = newPlanName
        self.reference = reference
        self.flowType = flowType
    }
}
