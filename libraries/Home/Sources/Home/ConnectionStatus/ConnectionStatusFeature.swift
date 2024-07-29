//
//  Created on 09/06/2023.
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

import ComposableArchitecture

import Domain
import VPNAppCore
import Localization

@Reducer
public struct ConnectionStatusFeature {

    @ObservableState
    public struct State: Equatable {
        public var protectionState: ProtectionState

        @SharedReader(.userCountry) public var userCountry: String?
        @SharedReader(.userIP) public var userIP: String?

        public init(protectionState: ProtectionState) {
            self.protectionState = protectionState
        }
    }

    public enum Action: Equatable {
        case maskLocationTick

        case watchConnectionStatus
        case newConnectionStatus(VPNConnectionStatus)
    }

    private enum CancelId {
        case watchConnectionStatus
    }

    public init() { }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .maskLocationTick:
                if case let .protecting(country, ip) = state.protectionState {
                    if let masked = partiallyMaskedLocation(country: country, ip: ip) {
                        state.protectionState = masked
                    }
                }
                return .run { action in
                    try await Task.sleep(nanoseconds: 50_000_000)
                    await action(.maskLocationTick)
                }.cancellable(id: MaskLocation.task, cancelInFlight: true)

            case .watchConnectionStatus:
                @Dependency(\.vpnConnectionStatusPublisher) var vpnConnectionStatusPublisher
                return .publisher { vpnConnectionStatusPublisher().receive(on: UIScheduler.shared).map(Action.newConnectionStatus) }
                    .cancellable(id: CancelId.watchConnectionStatus)

            case .newConnectionStatus(let status):
                let code = state.userCountry
                let displayCountry = LocalizationUtility.default.countryName(forCode: code ?? "")
                state.protectionState = status.protectionState(country: displayCountry ?? "", ip: state.userIP ?? "")
                guard case .protecting = state.protectionState else {
                    return .cancel(id: MaskLocation.task)
                }
                return .send(.maskLocationTick)
            }
        }
    }

    enum MaskLocation {
        case task
    }

    func partiallyMaskedLocation(country: String, ip: String) -> ProtectionState? {
        let replacedCountry = country.partiallyMasked()
        let replacedIP = ip.partiallyMasked()
        if let replacedIP, let replacedCountry {
            if Bool.random() {
                return .protecting(country: replacedCountry, ip: ip)
            } else {
                return .protecting(country: country, ip: replacedIP)
            }
        } else if let replacedIP {
            return .protecting(country: country, ip: replacedIP)
        } else if let replacedCountry {
            return .protecting(country: replacedCountry, ip: ip)
        }
        return nil
    }
}
