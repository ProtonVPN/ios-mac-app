//
//  Created on 25/04/2023.
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

// MARK: - Start SwiftUI Life cycle
import SwiftUI
import Theme
import Home
import Home_iOS
import ConnectionDetails
import ConnectionDetails_iOS
import vpncore
import VPNShared
import VPNAppCore
import Settings

import ComposableArchitecture

struct AppReducer: ReducerProtocol {
    struct State: Equatable {
        var selectedTab: Tab

        var home: HomeFeature.State
        var connectionScreenState: ConnectionScreenFeature.State?
        // var countries: CountriesFeature.State
        var settings: SettingsFeature.State

    }

    enum Tab {
        case home
        case countries
        case settings
    }

    enum Action: Equatable {
        case selectedTabChanged(Tab)
        case home(HomeFeature.Action)
        case connectionScreenAction(ConnectionScreenFeature.Action)
        case connectionScreenDismissed
        case settings(SettingsFeature.Action)
    }

    var body: some ReducerProtocolOf<Self> {
        Reduce { state, action in
            switch action {
            case .selectedTabChanged(let tab):
                state.selectedTab = tab
                return .none

            case .home(.showConnectionDetails):
                state.connectionScreenState = ConnectionScreenFeature.State(
                    ipViewState: IPViewFeature.State(localIP: "127.0.0.1",
                                                     vpnIp: "102.107.197.6"),
                    connectionDetailsState: ConnectionDetailsFeature.State(connectedSince: Date.init(timeIntervalSinceNow: -12345),
                                                                           country: "Lithuania",
                                                                           city: "Siauliai",
                                                                           server: "LT#5",
                                                                           serverLoad: 23,
                                                                           protocolName: "WireGuard"),
                    connectionFeatures: [.p2p, .tor, .smart, .streaming],
                    isSecureCore: true
                )
                return .none

            case .connectionScreenAction(.close), .connectionScreenDismissed:
                state.connectionScreenState = nil
                return .none

            case .home(.connect(let specs)):
                @Dependency(\.connectToVPN) var connectToVPN
                connectToVPN(specs)
                return .none

            case .home(.disconnect):
                @Dependency(\.disconnectVPN) var disconnectVPN
                disconnectVPN()
                return .none

            case .home:
                return .none

            case .connectionScreenAction:
                return .none
            case .settings:
                return .none
            }
        }
        Scope(state: \.home, action: /Action.home) {
            HomeFeature()
        }
        Scope(state: \.settings, action: /Action.settings) { 
            SettingsFeature() 
        }
    }
}

#if REDESIGN
@main
struct ProtonVPNApp: App {
    /// This delegates the app lifecycle events to the old `AppDelegate`. Once we have a working redesign we can start moving away from `AppDelegate`
    /// Until then it's the safest option to keep the functionality intact.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.scenePhase) var scenePhase

    let store: StoreOf<AppReducer>

    init() {
        @Dependency(\.initialStateProvider) var initialStateProvider
        _ = DependencyContainer.shared.makeAppStateManager()

        UITabBar.appearance().backgroundColor = .color(.background, .weak)
        UITableView.appearance().backgroundColor = .color(.background, .strong)

        self.store = .init(
            initialState: initialStateProvider.initialState,
            reducer: AppReducer()
                .dependency(\.watchVPNConnectionStatus, WatchAppStateChangesKey.watchVPNConnectionStatusChanges)
            #if targetEnvironment(simulator)
                .dependency(\.connectToVPN, SimulatorHelper.shared.connect)
                .dependency(\.disconnectVPN, SimulatorHelper.shared.disconnect)
            #else
                .dependency(\.connectToVPN, ConnectToVPNKey.bridgedAutoConnect)
                .dependency(\.disconnectVPN, DisconnectVPNKey.bridged)
            #endif
                ._printChanges()
        )
    }

    var body: some Scene {
        WindowGroup {
            WithViewStore(self.store, observe: { $0 }) { viewStore in
                TabView(
                    selection: viewStore.binding(
                        get: \.selectedTab,
                        send: AppReducer.Action.selectedTabChanged
                    )
                ) {
                    HomeView(store: store.scope(state: \.home, action: AppReducer.Action.home))
                        .homeTabItem()
                        .tag(AppReducer.Tab.home)
                    CountriesView()
                        .countriesTabItem()
                        .tag(AppReducer.Tab.countries)
                    SettingsView(store: store.scope(state: \.settings, action: AppReducer.Action.settings))
                        .settingsTabItem()
                        .tag(AppReducer.Tab.settings)
                }
                .tint(Color(.text, .interactive))
                .onOpenURL { url in // deeplinks
                    log.debug("Received URL: \(url)")
                }

                .sheet(unwrapping: viewStore.binding(get: \.connectionScreenState, send: .connectionScreenDismissed),
                       content: { binding in
                    ConnectionScreenView(store: store.scope(state: { _ in binding.wrappedValue }, action: AppReducer.Action.connectionScreenAction ))
                })

            }
        }
        .onChange(of: scenePhase) { newScenePhase in // The SwiftUI lifecycle events
            switch newScenePhase {
            case .active:
                log.debug("App is active")
            case .inactive:
                log.debug("App is inactive")
            case .background:
                log.debug("App is in background")
            @unknown default:
                log.debug("Received an unexpected new value.")
            }
        }
    }
}
#endif
// MARK: - End SwiftUI Life cycle
