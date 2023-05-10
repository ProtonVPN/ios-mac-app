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

import SwiftUI
import Theme
import Theme_macOS

struct SideBarItemView: View {
    let category: SideBarTab
    @Binding var selectedTab: SideBarTab

    var body: some View {
        Button {
            selectedTab = category
        } label: {
            HStack(spacing: 0) {
                Label {
                    Text(category.title)
                } icon: {
                    category.image
                        .resizable()
                        .frame(maxWidth: 16, maxHeight: 16)
                        .tint(Color(.text))
                }
                Spacer()
            }
        }
        .frame(minWidth: 160)
        .buttonStyle(SideBarButtonStyle(isActive: selectedTab == category))
    }
}

struct SideBarItemView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            SideBarItemView(category: .home,
                            selectedTab: .init(get: { .home },
                                               set: { _ in }))
            SideBarItemView(category: .countries,
                            selectedTab: .init(get: { .home },
                                               set: { _ in }))
            SideBarItemView(category: .settings,
                            selectedTab: .init(get: { .home },
                                               set: { _ in }))
        }
        .previewLayout(.fixed(width: 200, height: 32 * 3))
    }
}
