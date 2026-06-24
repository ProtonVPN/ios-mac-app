//
//  Created on 06.07.2026 by John Biggs.
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
@testable import HomeShared
import SwiftUI
import Theme

/// Hosts `HomeMapView` for the map snapshot sweeps, framed the way the home screen frames it: the globe is
/// fitted into the map band that shows above the connection card, and the render canvas continues
/// underneath to the bottom of the screen. Handing the full screen height to the map instead would zoom
/// and crop countries quite differently from what the app shows.
struct MapSnapshotScreen: View {
    let store: StoreOf<HomeMapFeature>
    let title: String
    let size: CGSize

    private enum Dimensions {
        /// Height of the home screen's bottom chrome, the connection card and the recents peek, measured
        /// from the Home screen snapshots. The map band is what remains above it.
        static let bottomChromeHeight: CGFloat = 240
    }

    var body: some View {
        ZStack {
            HomeMapView(
                store: store,
                availableHeight: size.height - Dimensions.bottomChromeHeight,
                availableWidth: size.width,
                renderHeight: size.height
            )
            .frame(size)
            .background(Color(.background))
            .environment(\.colorScheme, .dark)
            // Render the globe via off-screen Metal read-back, since a live MTKView can't be captured
            // by the snapshot strategy's `layer.render(in:)`.
            .environment(\.globeRenderMode, .staticImage)
            VStack {
                Text(title)
                    .foregroundStyle(.white)
                    .font(.hero)
                    .padding(.top, .themeSpacing64)
                Spacer()
            }
        }
    }
}
