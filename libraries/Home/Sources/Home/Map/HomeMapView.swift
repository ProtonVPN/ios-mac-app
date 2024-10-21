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

    let availableHeight: CGFloat
    let availableWidth: CGFloat

    var store: StoreOf<HomeMapFeature>

    public init(store: StoreOf<HomeMapFeature>, availableHeight: CGFloat, availableWidth: CGFloat) {
        self.store = store
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
    }

    var shouldShowPin: Bool {
        if case .connected = store.vpnConnectionStatus { // we're connected to a known country {
            return true
        }
        return store.userCountry != nil // or we know the user country
    }

    public var body: some View {
        ZStack {
            map
            MapPin(mode: store.pinMode)
                .scaleEffect(1 / mapScale()) // pin scales together with the map, so we need to counter it to preserve the original size
                .offset(pinOffset())
                .opacity(shouldShowPin ? 1 : 0)
        }
        .frame(width: map.svg?.bounds().width,
               height: map.svg?.bounds().height)
        .scaleEffect(mapScale())
        .offset(mapOffset())
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: store.mapState.code) {
            map = SVGView.naturalEarthMap
            guard let code = store.mapState.code ?? store.userCountry else { return }
            map.node(code: code.lowercased()).map {
                map.highlight(node: $0)
            }
        }
    }

    private func pinOffset() -> CGSize {
        guard let code = (store.mapState.code ?? store.userCountry)?.lowercased(),
              let coordinates = store.mapState.coordinates ?? CountriesCoordinates.countryCenterCoordinates(code.uppercased()),
              let mapBounds = map.svg?.bounds().size else {
            return .zero
        }
        let location = CLLocationCoordinate2D(latitude: coordinates.latitude,
                                              longitude: coordinates.longitude - 10) // -10 to account for the shifted map
        let projection = NaturalEarthProjection.projection(from: location, in: mapBounds)
        return .init(width: projection.x, height: -projection.y)
    }

    private func mapOffset() -> CGSize {
        guard let code = (store.mapState.code ?? store.userCountry)?.lowercased(),
              let node = map.node(code: code),
              let mapBounds = map.svg?.bounds() else {
            return .zero
        }

        let scale = mapScale()
        return .init(width: (mapBounds.midX - node.bounds().midX) * scale,
                     height: (mapBounds.midY - node.bounds().midY) * scale)
    }

    private func mapScale() -> CGFloat {
        guard let code = (store.mapState.code ?? store.userCountry)?.lowercased(),
              let node = map.node(code: code) else {
            return wholeMapScale()
        }
        let scaleX = (availableWidth - 40) / node.bounds().width  // 40 is the padding
        let scaleY = (availableHeight - 40) / node.bounds().height

        return min(min(scaleX, scaleY), 4) // max scale, useful for small countries
    }

    private func wholeMapScale() -> CGFloat {
        guard let mapBounds = map.svg?.bounds() else { return 1 }
        let scaleX = availableWidth / mapBounds.width
        let scaleY = availableHeight / mapBounds.height
        return min(scaleX, scaleY)
    }
}
