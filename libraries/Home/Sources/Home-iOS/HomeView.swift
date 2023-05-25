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

import ComposableArchitecture

import Home
import Theme
import Theme_iOS
import Ergonomics

public struct HomeTabView: View {
    public init() {}
    public var body: some View {
        Text("home")
    }
}

public struct HomeView: View {
    typealias ActionSender = (HomeFeature.Action) -> ViewStoreTask
    let store: StoreOf<HomeFeature>

    static let mapHeight: CGFloat = 300

    @State var notchOffset: CGFloat = 0

    /// Used for determining the offset for the safe area (notch, etc) at the top of the screen
    var notchReader: some View {
        Rectangle()
            .fill(Color.clear)
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        notchOffset = proxy.frame(in: .global).minY
                    }
                }
            )
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            let item = viewStore.state.mostRecent ?? .defaultFastest
            ScrollView {
                ZStack(alignment: .top) {
                    HomeMapView()
                        .frame(minHeight: Self.mapHeight)

                    notchReader

                    HomeHeaderView(
                        connected: false,
                        location: .region(code: "LT"),
                        notchOffset: notchOffset,
                        mapHeight: Self.mapHeight
                    )
                }
                HomeConnectionCardView(
                    item: item,
                    connected: false,
                    sendAction: { _ = viewStore.send($0) }
                )
                VStack(spacing: 0) {
                    if !viewStore.remainingPinnedConnections.isEmpty {
                        HomeRecentsSectionView(
                            items: viewStore.state.remainingPinnedConnections,
                            pinnedSection: true,
                            sendAction: { _ = viewStore.send($0) }
                        )
                    }
                    if !viewStore.remainingRecentConnections.isEmpty {
                        HomeRecentsSectionView(
                            items: viewStore.state.remainingRecentConnections,
                            pinnedSection: false,
                            sendAction: { _ = viewStore.send($0) }
                        )
                    }
                }
            }
            .background(Color(.background))
        }
    }

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }
}

internal extension GeometryProxy {
    var scrollOffset: CGFloat {
        frame(in: .global).minY
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

extension FlagAppearance {
    static let iOS: Self = .init(
        secureCoreFlagShadowColor: .black.opacity(0.4),
        secureCoreFlagCurveColor: .init(.icon, .hint),
        fastestAccentColor: FastestFlagView.boltColor,
        fastestBackgroundColor: Theme.Asset.sharedPineBase.swiftUIColor.opacity(0.3)
    )
}

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(store: .init(initialState: .preview, reducer: HomeFeature()))
    }
}
#endif
