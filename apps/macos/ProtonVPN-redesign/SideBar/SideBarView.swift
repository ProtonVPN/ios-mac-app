//
//  Created on 04/05/2023.
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

import SwiftUI
import Theme
import Home_macOS

struct SideBarView: View {

    // Don’t try to use the List selection API for navigation. It only exists to support single or multiple item selection of items in edit mode.
    @State private var selectedTab: SideBarTab?

    @State private var isHomeTabActive = true
    @State private var connectionDetailsVisible = false

    var body: some View {
        NavigationView {
            List(selection: $selectedTab) {
                NavigationLink(destination: HomeView(connectionDetailsVisible: $connectionDetailsVisible),
                               isActive: $isHomeTabActive) {
                    SideBarItemView(category: .home)
                }
                .tag(SideBarTab.home)
                NavigationLink(destination: CountriesView(isHomeTabActive: $isHomeTabActive)) {
                    SideBarItemView(category: .countries)
                }
                .tag(SideBarTab.countries)
                NavigationLink(destination: SettingsView()) {
                    SideBarItemView(category: .settings)
                }
                .tag(SideBarTab.settings)
            }

            .listStyle(SidebarListStyle())
            .toolbar {
                Asset.icSidePanelLeft.swiftUIImage
                    .resizable()
                    .foregroundColor(Color(.text, .weak))
                    .frame(width: 16, height: 16)
                    .onTapGesture {
                        toggleSidebar()
                    }
            }
        }
    }

    private func toggleSidebar() {
        // There is no other way that I found to programatically toggle the sidebar.
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}
