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
    /// How many points of the backdrop's bottom the sheet covers. The globe still renders under it, but its focus
    /// region ends where the sheet begins, so targets center in what the user can see.
    private let bottomOverlap: CGFloat
    /// The overlap of the sheet at its next rest, which informs the camera framing.
    private let restingOverlap: CGFloat
    private let showsInteractivePins: Bool
    /// Measured height of the connection header, to keep the globe out from under the lock and title.
    @State private var headerHeight: CGFloat = 0

    public init(
        map: StoreOf<HomeMapFeature>,
        status: StoreOf<ConnectionStatusFeature>,
        bottomOverlap: CGFloat = 0,
        restingOverlap: CGFloat = 0,
        showsInteractivePins: Bool = true
    ) {
        self.map = map
        self.status = status
        self.bottomOverlap = bottomOverlap
        self.restingOverlap = restingOverlap
        self.showsInteractivePins = showsInteractivePins
    }

    public var body: some View {
        // One reader, and it stays inside the safe area, because only a reader that still participates in the safe
        // area is told what the insets are. Measured on an iPhone 17 Pro, whose screen is 402 x 874: this reader
        // reports size 402 x 778 with insets of 62 top and 34 bottom, while a reader that ignores the safe area
        // reports the full 402 x 874 but insets of zero. Neither one answers both questions, so the size is put back
        // together here (778 + 62 + 34 = 874) and the content is pushed back out to it with `ignoresSafeArea`.
        //
        // That screen-sized canvas is the single space everything below is measured in: the globe renders into it,
        // the sheet reports its coverage counted from the window's bottom edge, and taps unproject through the same
        // numbers. Sharing one space is what keeps any of it from needing a correcting offset.
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let width = proxy.size.width + insets.leading + insets.trailing
            let canvas = proxy.size.height + insets.top + insets.bottom
            // What is actually free to look at: below the lock and title, above the sheet.
            let framedTop = insets.top + headerHeight
            // The globe is always scaled to the whole canvas and only centered within what is free, so moving the
            // sheet slides it at a constant size. The floor keeps a sheet raised over the whole map from centering
            // the user pin and the country that contains it to the very top edge.
            let visible = max(canvas - framedTop - bottomOverlap, canvas * Constants.minimumVisibleFraction)
            let restingVisible = max(
                canvas - framedTop - (restingOverlap > 0 ? restingOverlap : bottomOverlap),
                canvas * Constants.minimumVisibleFraction
            )

            ZStack(alignment: .top) {
                HomeMapView(
                    store: map,
                    availableHeight: canvas,
                    availableWidth: width,
                    renderHeight: canvas,
                    topInset: framedTop,
                    visibleHeight: visible,
                    restingVisibleHeight: restingVisible,
                    showsInteractivePins: showsInteractivePins
                )
                .frame(width: width, height: canvas, alignment: .top)

                // Padded below the status bar by hand, since this space starts at the screen's top edge.
                ConnectionStatusView(store: status) { headerHeight = $0 }
                    .padding(.top, insets.top)
            }
            .frame(width: width, height: canvas, alignment: .top)
            .ignoresSafeArea()
        }
        .background(Color(.background).ignoresSafeArea())
    }

    private enum Constants {
        /// The visible region never counts as less than this share of the canvas, however much the sheet covers.
        /// Without this, the map centering logic tries to keep the user pin visible above the full-screen sheet,
        /// which looks a little weird.
        static let minimumVisibleFraction: CGFloat = 0.25
    }
}
