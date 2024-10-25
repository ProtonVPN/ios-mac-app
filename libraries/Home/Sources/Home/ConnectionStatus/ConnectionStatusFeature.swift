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
import NetShield
import VPNAppCore
import Localization

@Reducer
public struct ConnectionStatusFeature {

    @ObservableState
    public struct State: Equatable {
        @Shared(.protectionState) public var protectionState: ProtectionState
        @SharedReader(.userCountry) public var userCountry: String?
        @SharedReader(.userIP) public var userIP: String?
        @SharedReader(.vpnConnectionStatus) public var vpnConnectionStatus: VPNConnectionStatus

        public var stickToTop: Bool = false

        public init() {
            
        }
    }

    @CasePathable
    public enum Action: Equatable {
        case maskLocationTick

        case watchConnectionStatus
        case newConnectionStatus(VPNConnectionStatus)
        case newProtectionState(ProtectionState)
        case newNetShieldStats(NetShieldModel)
        case stickToTop(Bool)
    }

    private enum CancelId {
        case watchConnectionStatus
    }

    public init() { }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .maskLocationTick:
                if case let .protecting(country, ip) = state.protectionState {
                    if let masked = partiallyMaskedLocation(country: country, ip: ip) {
                        if masked == state.protectionState {
                            // fully masked already
                            return .cancel(id: MaskLocation.task)
                        }
                        state.protectionState = masked
                    }
                }
                return .run { action in
                    try await Task.sleep(nanoseconds: 50_000_000)
                    await action(.maskLocationTick)
                }.cancellable(id: MaskLocation.task, cancelInFlight: true)

            case .watchConnectionStatus:
                return .merge([
                    .publisher {
                        state
                            .$vpnConnectionStatus
                            .publisher
                            .receive(on: UIScheduler.shared)
                            .map(Action.newConnectionStatus)
                    }.cancellable(id: CancelId.watchConnectionStatus),
                    .run { @MainActor send in
                        @Dependency(\.netShieldStatsProvider) var provider
                        send(.newNetShieldStats(await provider.getStats()))
                        for await stats in provider.statsStream() {
                            send(.newNetShieldStats(stats))
                        }
                    }.cancellable(id: CancelId.watchConnectionStatus)
                ])

            case .newConnectionStatus(let status):
                let code = state.userCountry
                let displayCountry = LocalizationUtility.default.countryName(forCode: code ?? "")
                let userIP = state.userIP
                return .run { send in
                    // Determine protection state and fetch NetShield stats
                    let protectionState = await status.protectionState(country: displayCountry ?? "", ip: userIP ?? "")
                    await send(.newProtectionState(protectionState))
                }

            case .newProtectionState(let protectionState):
                state.protectionState = protectionState
                if case .protecting = protectionState {
                    return .send(.maskLocationTick)
                } else {
                    return .cancel(id: MaskLocation.task)
                }

            case .newNetShieldStats(let netShieldModel):
                state.protectionState = state.protectionState.copy(withNetShield: netShieldModel)
                return .none

            case .stickToTop(let stickToTop):
                state.stickToTop = stickToTop
                return .none
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
