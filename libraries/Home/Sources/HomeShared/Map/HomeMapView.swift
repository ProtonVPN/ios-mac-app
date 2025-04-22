//
//  Created on 17/09/2024.
//
//  Copyright (c) 2024 Proton AG
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
import SVGView
import ComposableArchitecture
import Ergonomics
import Domain
import CoreLocation

public struct HomeMapView: View {
    let store: StoreOf<HomeMapFeature>

    private let mapBounds: CGRect
    private let availableHeight: CGFloat
    private let availableWidth: CGFloat

    @State private var pinMode: MapPin.Mode = .disconnected

    public init(store: StoreOf<HomeMapFeature>, availableHeight: CGFloat, availableWidth: CGFloat) {
        self.store = store
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
        self.mapBounds = SVGView.mapBounds
    }

    public var body: some View {
        WithPerceptionTracking {
            ZStack {
                SVGView.map
                MapPin(mode: .constant(store.pinMode))
                    .scaleEffect(1 / mapScale()) // pin scales together with the map, so we need to counter it to preserve the original size
                    .offset(store.pinOffset)
                    .opacity(store.shouldShowPin ? 1 : 0)
            }
            .frame(width: mapBounds.width, height: mapBounds.height)
            .scaleEffect(mapScale())
            .offset(mapOffset())
        }
    }

    private func mapOffset() -> CGSize {
        guard let code = (store.mapState.code ?? store.userCountry)?.lowercased(),
              let node = SVGView.mapSVG.mainlandNode(code: code) else {
            return .zero
        }

        let scale = mapScale()
        return .init(width: (mapBounds.midX - node.bounds().midX) * scale,
                     height: 40 + (mapBounds.midY - node.bounds().midY) * scale) // move the map 40 points down to avoid connection status and netshield stats
    }

    private func mapScale() -> CGFloat {
        guard let code = (store.mapState.code ?? store.userCountry)?.lowercased(),
              let node = SVGView.mapSVG.mainlandNode(code: code) else {
            return wholeMapScale()
        }
        let scaleX = (availableWidth - 40) / node.bounds().width  // 40 is the horizontal padding
        let scaleY = (availableHeight - 150) / node.bounds().height // 150 is the vertical padding. We need it for connection status and netshield stats

        return min(min(scaleX, scaleY), 4) // max scale, useful for small countries
    }

    private func wholeMapScale() -> CGFloat {
        let scaleX = availableWidth / mapBounds.width
        let scaleY = availableHeight / mapBounds.height
        return min(scaleX, scaleY)
    }
}
