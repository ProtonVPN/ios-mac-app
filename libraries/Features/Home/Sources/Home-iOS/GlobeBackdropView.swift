//
//  Created on 28/07/2026.
//
//  Copyright (c) 2026 Proton AG
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

import ComposableArchitecture
import HomeShared
import SwiftUI
import Theme

/// The globe backdrop view filling the window, with the connection header drawn on top. The tabs are presented above
/// this in a sheet, so whatever the sheet does not cover is what the user sees of the map.
public struct GlobeBackdropView: View {
    private let map: StoreOf<HomeMapFeature>
    private let status: StoreOf<ConnectionStatusFeature>

    public init(map: StoreOf<HomeMapFeature>, status: StoreOf<ConnectionStatusFeature>) {
        self.map = map
        self.status = status
    }

    public var body: some View {
        GeometryReader { proxy in
            // The globe draws through the safe areas, and its focus region is offset down by the top inset
            // so the framed country stays clear of the status bar while the canvas fills the screen.
            let topInset = proxy.safeAreaInsets.top
            let height = proxy.size.height + topInset + proxy.safeAreaInsets.bottom

            HomeMapView(
                store: map,
                availableHeight: height,
                availableWidth: proxy.size.width,
                topInset: topInset
            )
            .frame(width: proxy.size.width, height: height, alignment: .top)
            .overlay(alignment: .top) {
                ConnectionStatusView(store: status)
                    .padding(.top, topInset)
            }
        }
        .ignoresSafeArea()
        .background(Color(.background).ignoresSafeArea())
    }
}
