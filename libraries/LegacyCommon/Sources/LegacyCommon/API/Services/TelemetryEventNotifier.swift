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

import Foundation
import Combine
import Reachability

public class TelemetryEventNotifier {
    typealias ModalSource = UpsellEvent.ModalSource

    weak var telemetryService: TelemetryService?

    private var cancellables = Set<AnyCancellable>()

    init() {
        startObserving()
    }

    private func startObserving() {
        NotificationCenter.default
            .publisher(for: .reachabilityChanged)
            .sink(receiveValue: reachabilityChanged)
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: VpnGateway.connectionChanged)
            .compactMap { $0.object as? ConnectionStatus }
            .removeDuplicates()
            .sink(receiveValue: vpnGatewayConnectionChanged)
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .userInitiatedVPNChange)
            .sink(receiveValue: userInitiatedVPNChange)
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .upsellAlertWasDisplayed)
            .compactMap { $0.object as? UpsellEvent.ModalSource }
            .sink(receiveValue: upsellDisplayed)
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .userEngagedWithUpsellAlert)
            .compactMap { $0.object as? UpsellEvent.ModalSource }
            .sink(receiveValue: upsellEngaged)
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .userCompletedUpsellAlertJourney)
            .sink(receiveValue: upsellCompleted)
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .userEngagedWithAnnouncement)
            .map { $0.object as? String }
            .sink(receiveValue: announcementEngaged)
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .userWasDisplayedAnnouncement)
            .map { $0.object as? String }
            .sink(receiveValue: announcementDisplayed)
            .store(in: &cancellables)
    }

    private func reachabilityChanged(_ notification: Notification) {
        guard notification.name == .reachabilityChanged,
            let reachability = notification.object as? Reachability else {
            return
        }
        let networkType: ConnectionDimensions.NetworkType
        switch reachability.connection {
        case .unavailable, .none:
            networkType = .other
        case .wifi:
            networkType = .wifi
        case .cellular:
            networkType = .mobile
        }
        telemetryService?.reachabilityChanged(networkType)
    }

    private func userInitiatedVPNChange(_ notification: Notification) {
        guard notification.name == .userInitiatedVPNChange,
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

    private func upsellDisplayed(_ source: ModalSource?) {
        do {
            try telemetryService?.upsellEvent(.display, modalSource: source, newPlanName: nil)
        } catch {
            log.debug("No telemetry event triggered for upsell alert: \(String(describing: source)), error: \(error)", category: .telemetry)
        }
    }

    private func announcementDisplayed(_ offerReference: String?) {
        do {
            try telemetryService?.upsellEvent(.display, modalSource: .promoOffer, newPlanName: nil, offerReference: offerReference)
        } catch {
            log.debug("No telemetry event triggered for announcement offer: \(String(describing: offerReference)), error: \(error)", category: .telemetry)
        }
    }

    private func announcementEngaged(_ offerReference: String?) {
        do {
            try telemetryService?.upsellEvent(.upgradeAttempt, modalSource: .promoOffer, newPlanName: nil, offerReference: offerReference)
        } catch {
            log.debug("No telemetry event triggered for announcement offer: \(String(describing: offerReference)), error: \(error)", category: .telemetry)
        }
    }

    private func upsellEngaged(_ source: ModalSource?) {
        do {
            try telemetryService?.upsellEvent(.upgradeAttempt, modalSource: source, newPlanName: nil)
        } catch {
            log.debug("No telemetry event triggered for upsell alert: \(String(describing: source)), error: \(error)", category: .telemetry)
        }
    }

    private func upsellCompleted(_ notification: Notification) {
        guard let (source, newPlanName) = notification.object as? (ModalSource?, String?) else {
            assertionFailure("Notification object conversion failed in \(#function)")
            return
        }

        do {
            try telemetryService?.upsellEvent(.success, modalSource: source, newPlanName: newPlanName)
        } catch {
            log.debug("No telemetry event triggered for upsell alert: \(String(describing: source)), error: \(error)", category: .telemetry)
        }
    }
}
