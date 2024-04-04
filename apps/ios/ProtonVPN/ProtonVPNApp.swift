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

import ComposableArchitecture

import Domain
import Theme

import Home
import Home_iOS
import ConnectionDetails
import ConnectionDetails_iOS
import Settings
import Settings_iOS

import LegacyCommon
import VPNShared
import VPNAppCore

struct AppReducer: Reducer {
    struct State: Equatable {
        var selectedTab: Tab

        var home: HomeFeature.State
        var connectionScreenState: ConnectionScreenFeature.State?
        // var countries: CountriesFeature.State
        var settings: SettingsFeature.State
        public var vpnConnectionStatus: VPNConnectionStatus
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

        /// Watch for changes of VPN connection
        case watchConnectionStatus
        /// Process new VPN connection state
        case newConnectionStatus(VPNConnectionStatus)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .selectedTabChanged(let tab):
                state.selectedTab = tab
                return .none

            case .home(.showConnectionDetails):
                guard let status = state.vpnConnectionStatusInfo else { return .none }

                state.connectionScreenState = ConnectionScreenFeature.State(
                    ipViewState: IPViewFeature.State(localIP: "127.0.0.1",
                                                     vpnIp: "102.107.197.6"),
                    connectionSpec: status.0,
                    vpnConnectionActual: status.1
                )
                return .none

            case .connectionScreenAction(.close), .connectionScreenDismissed:
                state.connectionScreenState = nil
                return .none

            case .home(.connect(let specs)):
                return .run { _ in 
                    @Dependency(\.connectToVPN) var connectToVPN
                    try? await connectToVPN(specs)
                }

            case .home(.disconnect):
                return .run { _ in
                    @Dependency(\.disconnectVPN) var disconnectVPN
                    try? await disconnectVPN()
                }

            case .home:
                return .none

            case .connectionScreenAction:
                return .none
            case .settings:
                return .none

            case .watchConnectionStatus:
                return .run { send in
                    @Dependency(\.vpnConnectionStatusPublisher) var vpnConnectionStatusPublisher
                    
                    for await vpnStatus in vpnConnectionStatusPublisher().values {
                        await send(.newConnectionStatus(vpnStatus), animation: .default)
                    }
                }

            case .newConnectionStatus(let connectionStatus):
                state.vpnConnectionStatus = connectionStatus
                return .none

            }
        }
        Scope(state: \.home, action: /Action.home) {
            HomeFeature()
        }
        Scope(state: \.settings, action: /Action.settings) { 
            SettingsFeature() 
        }
        .ifLet(\.connectionScreenState, action: /Action.connectionScreenAction) {
            ConnectionScreenFeature()
        }

    }
}

extension AppReducer.State {
    var vpnConnectionStatusInfo: (ConnectionSpec, VPNConnectionActual?)? {
        switch vpnConnectionStatus {
        case .disconnected:
            return nil
        case .connected(let intent, let actual), .connecting(let intent, let actual), .loadingConnectionInfo(let intent, let actual), .disconnecting(let intent, let actual):
            return (intent, actual)
        }
    }
}

#if REDESIGN
struct ProtonVPNApp: App {
    /// This delegates the app lifecycle events to the old `AppDelegate`. Once we have a working redesign we can start moving away from `AppDelegate`
    /// Until then it's the safest option to keep the functionality intact.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.scenePhase) var scenePhase

    let store: StoreOf<AppReducer>

    init() {
        // Force all encoded objects to be decoded and recoded using the ProtonVPN module name
        setUpNSCoding(withModuleName: "ProtonVPN")

        @Dependency(\.initialStateProvider) var initialStateProvider
        _ = DependencyContainer.shared.makeAppStateManager()

        UITabBar.appearance().backgroundColor = .color(.background, .weak)
        UITableView.appearance().backgroundColor = .color(.background, .strong)

        self.store = .init(
            initialState: initialStateProvider.initialState,
            reducer: {
                AppReducer()
                    .dependency(\.vpnConnectionStatusPublisher, VPNConnectionStatusPublisherKey.watchVPNConnectionStatusChanges)
                    .dependency(\.settingsStorage, SettingsStorageKey.userDefaults)
#if targetEnvironment(simulator)
                    .dependency(\.connectToVPN, SimulatorHelper.shared.connect)
                    .dependency(\.disconnectVPN, SimulatorHelper.shared.disconnect)
#else
                    .dependency(\.connectToVPN, ConnectToVPNKey.bridgedConnect)
                    .dependency(\.disconnectVPN, DisconnectVPNKey.bridgedDisconnect)
#endif
                    ._printChanges()
            }
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
                .task { await viewStore.send(.watchConnectionStatus).finish() }

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
