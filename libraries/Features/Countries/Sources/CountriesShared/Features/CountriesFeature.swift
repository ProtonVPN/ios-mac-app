//
//  Created on 08/01/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import Dependencies
import Domain
import Strings
import VPNAppCore

@Reducer
public struct CountriesFeature {
    public init() {}

    @Reducer
    public enum Path {
        case search(SearchRoot)
        case country(CountryFeature)
    }

    @Reducer
    public enum Destination {
        // TODO: VPNAPPL-3313
//        case cityStateList
        case serversFeaturesInfo(ServersFeaturesInformationFeature)
        case serversStreamingFeaturesInfo(ServersStreamingFeaturesFeature)
        case discourageSecureCoreView(DiscourageSecureCoreFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var path = StackState<Path.State>()
        public var sections: IdentifiedArrayOf<CountrySectionFeature.State>

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        @Shared(.secureCoreToggle) public var isSecureCore: Bool
        @SharedReader(.userTier) var userTier: Int?
        @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus

        public init(sections: IdentifiedArrayOf<CountrySectionFeature.State>) {
            self.sections = sections
        }

        public var isConnectedToVPN: Bool {
            vpnConnectionStatus.is(\.connected)
        }

        public var enableViewToggle: Bool {
            !vpnConnectionStatus.is(\.connecting)
        }
    }

    @CasePathable
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        case secureCoreToggleRequested
        case applySecureCoreToggle

        // navigation path
        case path(StackActionOf<Path>)

        // sheets
        case destination(PresentationAction<Destination.Action>)

        // alerts
        case alert(PresentationAction<Alert>)

        // Section actions
        case sections(IdentifiedActionOf<CountrySectionFeature>)

        // Navigation
        case showFeaturesInfo
        case showServersStreamingFeaturesInfo
        case showSearch

        // Upsell actions
        case presentAllCountriesUpsell
        case presentCountryUpsell(String)
        case presentFreeConnectionsInfo

        case connectRequested(ConnectionSpec)

        @CasePathable
        public enum Alert {
            case disconnectAndToggle
            case cancel
        }
    }

    @Dependency(\.propertiesManager) private var propertiesManager

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .alert(.presented(.cancel)):
                state.alert = nil
                return .none

            case .alert(.presented(.disconnectAndToggle)):
                state.alert = nil
                // TODO: check if we can send it from here and if we need to send it from here
                AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.settingsChange)
                if state.isConnectedToVPN {
                    // TODO: Replace with actual VPN gateway action
                    print("vpnGateway.disconnect()")
                }
                return .send(.applySecureCoreToggle)

            case .secureCoreToggleRequested:
                return handleSecureCoreToggleRequest(&state)

            case .applySecureCoreToggle:
                return .none

            case .showFeaturesInfo:
                // differentiate between services/gateways
                state.destination = .serversFeaturesInfo(ServersFeaturesInformationFeature.State.servicesInfo)
                return .none

            case .showServersStreamingFeaturesInfo:
                state.destination =
                    .serversStreamingFeaturesInfo(ServersStreamingFeaturesFeature.State(countryName: "Country", streamingServices: IdentifiedArrayOf<StreamingServiceItem.State>())) // TODO: update in VPNAPPL-3313
                return .none

            case .showSearch:
                state.path.append(.search(SearchRoot.State.loading(state.sections)))
                return .none

            case .presentAllCountriesUpsell:
                print("Present AllCountriesUpsellAlert")
                return .none

            case let .presentCountryUpsell(countryCode):
                print("Present CountryUpsellAlert for: \(countryCode)")
                return .none

            case .presentFreeConnectionsInfo:
                print("Present FreeConnectionsAlert")
                return .none

            case .sections:
                return .none

            case .binding:
                return .none

            case .connectRequested:
                return .none

            case .path:
                return .none

            case .destination(.presented(.discourageSecureCoreView(.activateTapped))):
                if state.isConnectedToVPN {
                    state.alert = disconnectAlert
                    return .none
                }
                return .send(.applySecureCoreToggle)

            case .destination:
                return .none

            case .alert:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .forEach(\.sections, action: \.sections) {
            CountrySectionFeature()
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Private

    private func handleSecureCoreToggleRequest(_ state: inout State) -> Effect<Action> {
        let turningOn = !state.isSecureCore

        if turningOn {
            // Turning Secure Core ON

            // Check user tier
            if state.userTier?.isFreeTier == true {
                state.alert = upsellAlert // TODO: Should show upsell Oneclick instead VPNAPPL-3316
                return .none
            }

            // Check if we should show discourage view
            if propertiesManager.discourageSecureCore {
                state.destination = .discourageSecureCoreView(.init())
                return .none
            }

            // Check if connected - need to disconnect
            if state.isConnectedToVPN {
                state.alert = disconnectAlert
                return .none
            }

            // All checks passed, apply toggle
            return .send(.applySecureCoreToggle)
        } else {
            // Turning Secure Core OFF

            // Check if connected - need to disconnect
            if state.isConnectedToVPN {
                state.alert = disconnectAlert
                return .none
            }

            // Apply toggle directly
            return .send(.applySecureCoreToggle)
        }
    }

    // TODO: VPNAPPL-3316, Also used in all countries/country upsell
    private var upsellAlert: AlertState<Action.Alert> {
        AlertState(
            title: { TextState("Upsell screen Payments") }
        )
    }

    private var disconnectAlert: AlertState<Action.Alert> {
        AlertState(
            title: { TextState(Localizable.warning) },
            actions: {
                ButtonState(
                    action: .send(.disconnectAndToggle),
                    label: { TextState(Localizable.continue) }
                )
                ButtonState(
                    role: .cancel,
                    action: .send(.cancel),
                    label: { TextState(Localizable.cancel) }
                )
            },
            message: { TextState(Localizable.viewToggleWillCauseDisconnect) }
        )
    }
}

// MARK: - Path.State Equatable Conformance

extension CountriesFeature.Path.State: Equatable {}

extension CountriesFeature.Destination.State: Equatable {}
