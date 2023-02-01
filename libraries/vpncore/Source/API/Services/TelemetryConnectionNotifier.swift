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

public class TelemetryConnectionNotifier {
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
    }

    private func reachabilityChanged(_ notification: Notification) {
        guard notification.name == .reachabilityChanged,
            let reachability = notification.object as? Reachability else {
            return
        }
        let networkType: TelemetryDimensions.NetworkType
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
}
