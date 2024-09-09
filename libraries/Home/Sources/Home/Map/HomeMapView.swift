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

@available(iOS 17.0, *)
public struct HomeMapView: View {
    @State var map = SVGView.naturalEarthMap

    static let originalWidth: CGFloat = 2754
    static let originalHeight: CGFloat = 1398

    let availableHeight: CGFloat
    let availableWidth: CGFloat

    var store: StoreOf<HomeMapFeature>

    public init(store: StoreOf<HomeMapFeature>, availableHeight: CGFloat, availableWidth: CGFloat) {
        self.store = store
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
    }

    public var body: some View {
        ZStack {
            map
            MapPin(mode: store.pinMode)
                .scaleEffect(1 / mapScale(), anchor: .center)
                .offset(connectionOffset())
        }
        .frame(width: Self.originalWidth, height: Self.originalHeight)
        .scaleEffect(mapScale(), anchor: .center)
        .offset(offset())
        .onAppear {
            store.send(.onAppear)
        }
    }

    func connectionOffset() -> CGSize {
        guard let code = (store.mapState.code ?? store.userCountry)?.lowercased(),
              let coordinates = store.mapState.coordinates ?? CountriesCoordinates.countryCenterCoordinates(code.uppercased()) else {
            return .zero
        }
        let location = CLLocationCoordinate2D(latitude: coordinates.latitude,
                                              longitude: coordinates.longitude - 10) // -10 to account for the shifted map
        let projection = NaturalEarthProjection.projection(from: location,
                                                           in: .init(width: Self.originalWidth,
                                                                     height: Self.originalHeight))
        return .init(width: projection.x, height: -projection.y)
    }

    func offset() -> CGSize {
        guard let code = (store.mapState.code ?? store.userCountry)?.lowercased(),
              let node = map.node(code: code),
              let mapBounds = map.svg?.bounds() else {
            return .zero
        }

        let scale = mapScale()
        return .init(width: (mapBounds.midX - node.bounds().midX) * scale,
                     height: (mapBounds.midY - node.bounds().midY) * scale)
    }

    func mapScale() -> CGFloat {
        guard let code = (store.mapState.code ?? store.userCountry)?.lowercased(),
              let node = map.node(code: code) else {
            return availableWidth / Self.originalWidth // show the whole map
        }
        let scaleX = (availableWidth - 40) / node.bounds().width  // 40 is the padding
        let scaleY = (availableHeight - 40) / node.bounds().height

        return min(scaleX, scaleY) // TODO: [redesign] Consider also the available space when choosing which scale to use
    }
}
