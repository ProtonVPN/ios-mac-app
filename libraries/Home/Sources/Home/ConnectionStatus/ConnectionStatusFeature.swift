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

import SwiftUI

import Domain
import NetShield
import VPNAppCore
import Localization

@Reducer
public struct ConnectionStatusFeature {

    private static let timerDurationInMilliseconds: Int = 50

    @ObservableState
    public struct State: Equatable {
        @Shared(.protectionState) public internal(set) var protectionState: ProtectionState
        @SharedReader(.userCountry) public var userCountry: String?
        @SharedReader(.userIP) public var userIP: String?
        @SharedReader(.vpnConnectionStatus) public var vpnConnectionStatus: VPNConnectionStatus

        var startingProtectionState: ProtectionState = .unprotected

        public internal(set) var stickToTop: Bool = false

        public init() {}
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

    private enum MaskLocation {
        case task
    }

    private enum IDs {
        case watchConnectionStatus
        case maskLocation
        case protectionState
    }

    public init() { }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .maskLocationTick:
                if case let .protecting(country, ip) = state.protectionState {
                    if let masked = partiallyMaskedLocation(country: country, ip: ip) {
                        if masked == state.protectionState { // fully masked already
                            return .cancel(id: IDs.maskLocation)
                        }
                        state.protectionState = masked
                    }
                    return .run { action in
                        try await Task.sleep(nanoseconds: UInt64(Self.timerDurationInMilliseconds) * NSEC_PER_MSEC)
                        await action(.maskLocationTick)
                    }
                    .cancellable(id: IDs.maskLocation, cancelInFlight: true)
                } else {
                    return .cancel(id: IDs.maskLocation)
                }

            case .watchConnectionStatus:
                return .merge([
                    .publisher {
                        state
                            .$vpnConnectionStatus
                            .publisher
                            .receive(on: UIScheduler.shared)
                            .map(Action.newConnectionStatus)
                    },
                    .run { @MainActor send in
                        @Dependency(\.netShieldStatsProvider) var provider
                        send(.newNetShieldStats(await provider.getStats()))
                        for await stats in provider.statsStream() {
                            send(.newNetShieldStats(stats))
                        }
                    }
                ]).cancellable(id: IDs.watchConnectionStatus)

            case .newConnectionStatus(let status):
                let code = state.userCountry
                let displayCountry = LocalizationUtility.default.countryName(forCode: code ?? "") ?? ""
                let userIP = state.userIP ?? ""
                return .run { send in
                    // Determine protection state and fetch NetShield stats
                    let protectionState = await status.protectionState(country: displayCountry, ip: userIP)
                    await send(.newProtectionState(protectionState))
                }
                .debounce(id: IDs.protectionState, for: .milliseconds(Self.timerDurationInMilliseconds), scheduler: UIScheduler.shared)

            case .newProtectionState(let protectionState):
                // let's check that we're not already masking location twice with same data
                // THIS is a workaround... proper solution should make sure we're no receiving twice the same action
                // with same data ?!
                // we can debounce the action handling though but debounce delay cause unreactive UI...
                if case .protecting = protectionState {
                    // if it's a fresh new protection state...
                    if case .unprotected = state.startingProtectionState {
                        state.startingProtectionState = protectionState // let's store it
                    } else if protectionState == state.startingProtectionState {
                        return .none // however do nothing if we got the same protection state
                    }
                    state.protectionState = protectionState // store the new state
                    return .send(.maskLocationTick)
                } else {
                    state.protectionState = protectionState // store the new state
                    state.startingProtectionState = .unprotected // reset startingProtectionState
                    return .cancel(id: IDs.maskLocation)
                }

            case .newNetShieldStats(let netShieldModel):
                state.protectionState = state.protectionState.copy(withNetShield: netShieldModel)
                return .none

            case .stickToTop(let stickToTop):
                guard state.stickToTop != stickToTop else { return .none }
                state.stickToTop = stickToTop
                return .none
            }
        }
    }

    func partiallyMaskedLocation(country: String, ip: String) -> ProtectionState? {
        let replacedCountry = country.partiallyMasked()
        let replacedIP = ip.partiallyMasked(onlyAlphanumerics: true)
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
