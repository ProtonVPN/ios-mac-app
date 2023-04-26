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
import Home_iOS

@main
struct RedesignedVPNApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    enum Tab {
        case home
        case countries
        case settings
    }

    @State private var selectedTab: Tab = .home

    init() {
        UITabBar.appearance().backgroundColor = .color(.background, .weak)
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                HomeView()
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
        }
    }
}
// MARK: - End SwiftUI Life cycle
