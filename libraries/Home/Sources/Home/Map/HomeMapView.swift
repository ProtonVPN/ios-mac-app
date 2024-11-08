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
    @State private var renderedMapImage: Image?

    private let mapBounds: CGRect
    private let availableHeight: CGFloat
    private let availableWidth: CGFloat

    private var store: StoreOf<HomeMapFeature>

    public init(store: StoreOf<HomeMapFeature>, availableHeight: CGFloat, availableWidth: CGFloat) {
        self.store = store
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
        self.mapBounds = SVGView.mapBounds
    }

    private var shouldShowPin: Bool {
        if case .connected = store.vpnConnectionStatus { // we're connected to a known country {
            return true
        }
        return store.userCountry != nil // or we know the user country
    }

    public var body: some View {
        ZStack {
            renderedMapImage
            MapPin(mode: store.pinMode)
                .scaleEffect(1 / mapScale()) // pin scales together with the map, so we need to counter it to preserve the original size
                .offset(pinOffset())
                .opacity(shouldShowPin ? 1 : 0)
        }
        .frame(width: mapBounds.width,  height: mapBounds.height)
        .scaleEffect(mapScale())
        .offset(mapOffset())
        .onAppear {
            renderMap(focusedCountryCode: store.mapState.code ?? store.userCountry)
            store.send(.onAppear)
        }
        .onChange(of: store.mapState.code) {
            renderMap(focusedCountryCode: $0 ?? store.userCountry)
        }
    }

    @MainActor
    private func renderMap(focusedCountryCode: String?) {
        let scale = mapScale()
        log.info("Rendering map (focused on: \(optional: focusedCountryCode) @\(scale)x)")
        let renderer = ImageRenderer(content: MapRenderView(highlightedCountryCode: focusedCountryCode))
        renderer.scale = scale

        guard let uiImage = renderer.uiImage else {
            log.error("Failed to render map")
            return
        }
        renderedMapImage = Image(uiImage: uiImage)
    }

    private func pinOffset() -> CGSize {
        guard let code = (store.mapState.code ?? store.userCountry)?.lowercased(),
              let coordinates = store.mapState.coordinates ?? CountriesCoordinates.countryCenterCoordinates(code.uppercased()) else {
            return .zero
        }
        let location = CLLocationCoordinate2D(latitude: coordinates.latitude,
                                              longitude: coordinates.longitude - 10) // -10 to account for the shifted map
        let projection = NaturalEarthProjection.projection(from: location, in: mapBounds.size)
        return .init(width: projection.x, height: -projection.y)
    }

    private func mapOffset() -> CGSize {
        guard let code = (store.mapState.code ?? store.userCountry)?.lowercased(),
              let node = SVGView.idleMapView.node(code: code) else {
            return .zero
        }

        let scale = mapScale()
        return .init(width: (mapBounds.midX - node.bounds().midX) * scale,
                     height: (mapBounds.midY - node.bounds().midY) * scale)
    }

    private func mapScale() -> CGFloat {
        guard let code = (store.mapState.code ?? store.userCountry)?.lowercased(),
              let node = SVGView.idleMapView.node(code: code) else {
            return wholeMapScale()
        }
        let scaleX = (availableWidth - 40) / node.bounds().width  // 40 is the padding
        let scaleY = (availableHeight - 40) / node.bounds().height

        return min(min(scaleX, scaleY), 4) // max scale, useful for small countries
    }

    private func wholeMapScale() -> CGFloat {
        let scaleX = availableWidth / mapBounds.width
        let scaleY = availableHeight / mapBounds.height
        return min(scaleX, scaleY)
    }
}
