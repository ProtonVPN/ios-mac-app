//
//  Created on 16/05/2023.
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
import Strings
import Theme

public extension View {
    func settingsTabItem() -> some View {
        return self
            .tabItem {
                Label {
                    Text(Localizable.settingsTab)
                } icon: {
                    Theme.Asset.icCogWheel.swiftUIImage
                }
            }
    }

    func countriesTabItem() -> some View {
        return self
            .tabItem {
                Label {
                    Text(Localizable.countriesTab)
                } icon: {
                    Theme.Asset.icEarth.swiftUIImage
                }
            }
    }

    func homeTabItem() -> some View {
        return self
            .tabItem {
                Label {
                    Text(Localizable.homeTab)
                } icon: {
                    Theme.Asset.icHouseFilled.swiftUIImage
                }
            }
    }
}
