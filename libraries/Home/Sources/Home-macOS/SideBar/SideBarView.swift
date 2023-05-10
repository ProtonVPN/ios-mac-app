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

public struct SideBarView: View {

    @State private var connectionDetailsVisible = false

    @State private var sidebarActive: Bool = true
    @State private var backgroundActive: Bool = false
    @State private var selectedTab: SideBarTab = .home

    public init() {}

    public var body: some View {
        ZStack {
            if backgroundActive { // This background is made to block the pixels behind the sidebar from being visible while view moves to 0% opacity
                Color(.background).ignoresSafeArea()
            }
            HStack(spacing: 0) {
                if sidebarActive {
                    VStack(alignment: .leading, spacing: 0) {
                        SideBarItemView(category: .home, selectedTab: $selectedTab)
                        SideBarItemView(category: .countries, selectedTab: $selectedTab)
                        SideBarItemView(category: .settings, selectedTab: $selectedTab)
                        Spacer()
                        ProfileButtonView()
                    }
                    .fixedSize(horizontal: true, vertical: false) // don't allow for horizontal resizing the view when window resizes
                    .background(.ultraThickMaterial)
                }
                switch selectedTab {
                case .home:
                    HomeView(connectionDetailsVisible: $connectionDetailsVisible)
                    if connectionDetailsVisible {
                        ConnectionDetailsView()
                    }
                case .countries:
                    CountriesView {
                        selectedTab = .home
                    }
                case .settings:
                    SettingsView()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    toggleSidebar()
                }, label: {
                    Asset.icSidePanelLeft.swiftUIImage
                        .resizable()
                        .foregroundColor(Color(.text, .weak))
                        .frame(width: 16, height: 16)
                })
            }
        }
    }

    private func toggleSidebar() {
        if sidebarActive { // changing to hidden sidebar
            backgroundActive.toggle() // show the background immediately when it starts to hide
        } else { // hide the background after the showing animation finishes
            withAnimation(.easeIn(duration: 0.7)) { // 0.7 instead of 0.3 to prevent the view behind from seeing through the app window.
                backgroundActive.toggle()
            }
        }
        withAnimation(.easeOut(duration: 0.3)) {
            sidebarActive.toggle()
        }
    }
}

struct SideBarView_Previews: PreviewProvider {
    static var previews: some View {
        SideBarView()
    }
}
