//
//  Created on 25/04/2024.
//
//  Copyright (c) 2024 Proton AG
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

import SwiftUI

import ComposableArchitecture

struct MainView: View {
    
    @Bindable var store: StoreOf<MainFeature>

    var body: some View {
        TabView(selection: $store.currentTab.sending(\.selectTab)) {
            NavigationStack {
                CountryListView(store: store.scope(state: \.countryList,
                                                   action: \.countryList))
            }
            .tag(MainFeature.Tab.home)
            .tabItem { Text("Home") }

            NavigationStack {
                EmptyView()
            }
            .tag(MainFeature.Tab.search)
            .tabItem { Text("Search") }
            NavigationStack {
                SettingsView(store: store.scope(state: \.settings, 
                                                action: \.settings))
            }
            .tag(MainFeature.Tab.settings)
            .tabItem { Text("Settings") }
        }
        .background(background)
    }

    @ViewBuilder
    private var background: some View {
        // Only show the stage background for the drill down settings views
        if store.settings.destination != nil {
            Image(.backgroundStage)
        } else if store.currentTab == .home {
            CountryListBackgroundGradient(store: store)
        } else {
            Color.clear
        }
    }
}
