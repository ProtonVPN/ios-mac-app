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

import SwiftUI
import Home
import Theme
import Theme_iOS

public struct HomeTabView: View {
    public init() {}
    public var body: some View {
        Text("home")
    }
}

public struct HomeView: View {
    public init() {}
    public var body: some View {
        ZStack(alignment: .top) {
            HomeAsset.mainMap.swiftUIImage
                .resizable(resizingMode: .stretch)
                .ignoresSafeArea()
                .aspectRatio(contentMode: .fill)
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(.background, .danger).opacity(0.5), .clear],
                               startPoint: .top,
                               endPoint: .bottom)
                .ignoresSafeArea()
                VStack {
                    Spacer()
                        .frame(height: 20)
                    Theme.Asset.icLockOpenFilled2
                        .swiftUIImage
                        .foregroundColor(Color(.background, .danger))
                    Text("You are unprotected")
                    Text("Lithuania * 158.6.140.191")
                }
            }
            .frame(height: 200)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

public struct CountriesView: View {
    public init() {}
    public var body: some View {
        Text("Countries")
    }
}

public struct SettingsView: View {
    public init() {}
    public var body: some View {
        Text("Settings")
    }
}

public extension View {
    func settingsTabItem() -> some View {
        return self
            .tabItem {
                Label {
                    Text(LocalizedString.settingsTabBarTitle)
                } icon: {
                    Theme.Asset.icCogWheel.swiftUIImage
                }
            }
    }

    func countriesTabItem() -> some View {
        return self
            .tabItem {
                Label {
                    Text(LocalizedString.countriesTabBarTitle)
                } icon: {
                    Theme.Asset.icEarth.swiftUIImage
                }
            }
    }

    func homeTabItem() -> some View {
        return self
            .tabItem {
                Label {
                    Text(LocalizedString.homeTabBarTitle)
                } icon: {
                    Theme.Asset.icHouseFilled.swiftUIImage
                }
            }
    }
}
