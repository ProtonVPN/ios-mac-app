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
import Theme_iOS
import Home
import Home_iOS

import ComposableArchitecture

#if REDESIGN

struct AppReducer: Reducer {
    struct State {
        public var home: HomeFeature.State
//        public var countries: CountriesFeature.State
//        public var settings: SettingsFeature.State
    }

    enum Action: Equatable {
        case home(HomeFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: /Action.home) {
            HomeFeature()
        }
    }
}

@main
struct ProtonVPNApp: App {
    /// This delegates the app lifecycle events to the old `AppDelegate`. Once we have a working redesign we can start moving away from `AppDelegate`
    /// Until then it's the safest option to keep the functionality intact.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.scenePhase) var scenePhase

    enum Tab {
        case home
        case countries
        case settings
    }

    @State private var selectedTab: Tab = .home

    let store: StoreOf<AppReducer>

    init() {
        @Dependency(\.initialStateProvider) var initialStateProvider

        UITabBar.appearance().backgroundColor = .color(.background, .weak)

        self.store = .init(
            initialState: initialStateProvider.initialState,
            reducer: AppReducer()
        )
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                HomeView(store: store.scope(state: \.home, action: AppReducer.Action.home))
                    .homeTabItem()
                    .tag(Tab.home)
                CountriesView()
                    .countriesTabItem()
                    .tag(Tab.countries)
                SettingsView()
                    .settingsTabItem()
                    .tag(Tab.settings)
            }
            .tint(Color(.text, .interactive))
            .onOpenURL { url in // deeplinks
                log.debug("Received URL: \(url)")
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
// MARK: - End SwiftUI Life cycle

#endif
