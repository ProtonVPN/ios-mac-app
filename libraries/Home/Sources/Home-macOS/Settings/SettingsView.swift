//
//  Created on 07/05/2023.
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

import Home
import SwiftUI
import Theme
import Theme_macOS

public struct SettingsView: View {

    @State private var currentSubview: AnyView?
    @State private var title = LocalizedString.settingsTabBarTitle
    @State private var subviewTitle: String = ""

    private func showSubview(view: AnyView?, title: String) {
        withAnimation(.easeOut(duration: 0.3)) {
            currentSubview = view
        }
        if view != nil {
            self.subviewTitle = title
        }
    }

    public var body: some View {
        StackNavigationView(currentSubview: $currentSubview, subviewTitle: $subviewTitle, title: title) {
            VStack(alignment: .leading) {
                Spacer()
                // Below is just to showcase the navigation for settings page, don't mind the hardcoded strings.
                Button {
                    showSubview(view: AnyView(Text("Killswitch!")),
                                title: "Killswitch")
                } label: {
                    Text("Killswitch")
                }
                Button {
                    showSubview(view: AnyView(Text("Protocols!")),
                                title: "Protocols")
                } label: {
                    Text("Protocols")
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.background))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.background))
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
