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
import Ergonomics

@Reducer
public struct ConnectionStatusFeature {

    @ObservableState
    public struct State: Equatable {
        @Shared(.protectionState) package var protectionState: ProtectionState
        @SharedReader(.userCountry) package var userCountry: String?
        @SharedReader(.userIP) package var userIP: String?
        @SharedReader(.vpnConnectionStatus) package var vpnConnectionStatus: VPNConnectionStatus

        package var connectionStatusBanner: ConnectionStatusBannerFeature.State = .init()

        package internal(set) var stickToTop: Bool = false

        fileprivate(set) var startingProtectionState: ProtectionState = .resolving

        fileprivate(set) var isUsingConnectionPackage: Bool = true

        package init(isUsingConnectionPackage: Bool = true) {
            self.isUsingConnectionPackage = isUsingConnectionPackage
        }
    }

    @CasePathable
    public enum Action: Equatable {
        case startLocationMasking
        case maskLocationTick

        case watchConnectionStatus
        case newConnectionStatus(VPNConnectionStatus)
        case newProtectionState(ProtectionState)
        case newNetShieldStats(NetShieldModel)
        case stickToTop(Bool)

        case tearDown

        case connectionStatusBanner(ConnectionStatusBannerFeature.Action)
    }

    public init() { }

    private static let maskTickTimerDuration: Duration = .milliseconds(50)
    private static let statusDebounceIntervalInMilliseconds: Int = 50

    private enum MaskLocation {
        case task
    }

    private enum IDs {
        case watchConnectionStatus
        case maskLocationTimer
        case protectionState
    }

    @Dependency(\.netShieldStatsProvider) private var provider
    @Dependency(\.continuousClock) private var clock

    public var body: some Reducer<State, Action> {
        Scope(state: \.connectionStatusBanner, action: \.connectionStatusBanner) { ConnectionStatusBannerFeature() }

        Reduce { state, action in
            switch action {
            case .startLocationMasking:
                return .run { send in
                    for await _ in self.clock.timer(interval: Self.maskTickTimerDuration) {
                        await send(.maskLocationTick)
                    }
                }
                .cancellable(id: IDs.maskLocationTimer, cancelInFlight: true)

            case .maskLocationTick:
                guard case let .protecting(country, ip) = state.protectionState else {
                    return .cancel(id: IDs.maskLocationTimer)
                }
                if let masked = partiallyMaskedLocation(country: country, ip: ip) {
                    if masked == state.protectionState { // fully masked already
                        return .cancel(id: IDs.maskLocationTimer)
                    }
                    state.$protectionState.withLock { $0 = masked }
                }
                return .none

            case .watchConnectionStatus:
                var effects: [Effect<Action>] = [
                    .concatenate(
                        .cancel(id: IDs.watchConnectionStatus),
                        .publisher {
                            state
                                .$vpnConnectionStatus
                                .publisher
                                .removeDuplicates()
                                .receive(on: UIScheduler.shared)
                                .map(Action.newConnectionStatus)
                        }.cancellable(id: IDs.watchConnectionStatus)
                    )
                ]
                if !state.isUsingConnectionPackage {
                    effects.append(
                        .run { @MainActor send in
                            let initialValue = await provider.getStats()
                            send(.newNetShieldStats(initialValue))
                            for await stats in provider.statsStream() {
                                send(.newNetShieldStats(stats))
                            }
                        }
                    )
                }
                return .merge(effects)

            case .newConnectionStatus(let status):
                let code = state.userCountry
                let country = LocalizationUtility.default.countryName(forCode: code ?? "") ?? ""
                let userIP = state.userIP ?? ""
                let netShieldModel = state.protectionState.netShieldModel
                return .run { send in
                    // Determine protection state and fetch NetShield stats if necessary
                    // (awaiting for a `ProtectionState` here is not ideal; let's implement a dedicated client for this in the future)
                    let protectionState = await status.protectionState(country: country, ip: userIP, netShieldModel: netShieldModel)
                    await send(.newProtectionState(protectionState))
                }
                .debounce(
                    id: IDs.protectionState,
                    for: .milliseconds(Self.statusDebounceIntervalInMilliseconds),
                    scheduler: UIScheduler.shared
                )

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
                    state.$protectionState.withLock { $0 = protectionState } // store the new state
                    return .send(.startLocationMasking)
                } else {
                    withOptionalAnimation(protectionState.shouldAnimateChange ? .default : nil) {
                        state.$protectionState.withLock { $0 = protectionState }
                    }
                    state.startingProtectionState = .unprotected // reset startingProtectionState
                    return .cancel(id: IDs.maskLocationTimer)
                }

            case .newNetShieldStats(let netShieldModel):
                withOptionalAnimation {
                    state.$protectionState.withLock { $0 = state.protectionState.copy(withNetShield: netShieldModel) }
                }
                return .none

            case .stickToTop(let stickToTop):
                return .none // Revisit sticking to top when possible to fix this issue VPNAPPL-2539
                guard state.stickToTop != stickToTop else { return .none }
                state.stickToTop = stickToTop
                return .none

            case .connectionStatusBanner:
                return .none

            case .tearDown:
                return .cancel(id: IDs.watchConnectionStatus)
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

fileprivate extension ProtectionState {
    var shouldAnimateChange: Bool {
        if case .protected = self {
            return true
        } else if case .protectedSecureCore = self {
            return true
        }
        return false
    }
}
