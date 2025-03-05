//
//  Created on 27/09/2024.
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

import Foundation
import SVGView
import SwiftUI
import Domain

/// Optimization: render the map to an image to avoid expensive re-rendering of the `SVGView`
/// whenever it is occluded by the pin animation or recents/protection status bottom sheet
@available(iOS 17.0, *)
struct MapRenderView: View {
    var country: String?

    @State var svg = SVGView.makeSVG()

    var body: some View {
        SVGView(svg: svg)
            .onChange(of: country) { oldState, newState in
                log.debug("Rendering map (focused on: \(optional: newState)")
                updateWith(code: oldState, highlighted: false)
                updateWith(code: newState, highlighted: true)
            }
    }

    private func updateWith(code: String?, highlighted: Bool) {
        guard let code = code?.lowercased(),
              let node = svg.node(code: code) else { return }

        guard let codes = CountriesCoordinates.disputedCountries[code] else {
            // Easy, just (un)highlight the country
            node.fill(highlighted: highlighted)
            return
        }
        // We have some disputed territories, just (un)hide them all
        node.borders(hidden: highlighted)
        codes
            .compactMap(svg.node(code:))
            .forEach { $0.borders(hidden: highlighted) }
    }
}

extension SVGView {

    private static let xmlMap: XMLElement = {
        let url = Bundle.module.url(forResource: "BlankMap-World", withExtension: "svg")!
        let xml = DOMParser.parse(contentsOf: url)!

        let index = xml.contents.firstIndex { node in
            (node as? XMLElement)?.name == "style"
        }
        if let index {
            (xml.contents[index] as? XMLElement)?.contents = [XMLText(text: MapCSS.css)]
        }
        return xml
    }()

    /// Parsing the xml representation of our map is expensive, so this should be called as little as possible
    static func makeSVG() -> SVGNode {
        log.debug("Parsing map SVG...")
        guard let node = SVGParser.parse(xml: xmlMap) else {
            fatalError("Failed to parse map svg from xml")
        }
        return node
    }

    private static let idleMapSVG = makeSVG()

    /// Optimization: cache the disconnected map view in memory
    static let idleMapView: SVGView = SVGView(svg: idleMapSVG)

    static let mapBounds: CGRect = idleMapSVG.bounds()
}

extension SVGNode {
    private static let highlightedCountryColor = SVGColor(hex: "0x4A4658")
    private static let countryColor = SVGColor(hex: "0x292733")
    private static let borderColor = SVGColor(hex: "0x7B768D")
    private static let alternativeCountryCodes = [
        "gb": "uk",
    ]

    func node(code: String) -> SVGNode? {
        [
            code + "x", // add "x" so that by default we only consider mainland of each country
            code,
            Self.alternativeCountryCodes[code] // Try to find the node using alternative country codes if no node is found using the country codes above.
        ]
            .lazy
            .compactMap { $0.flatMap { self.getNode(byId: $0) } }
            .first
    }

    func fill(highlighted: Bool) {
        let fillColor = highlighted ? Self.highlightedCountryColor : Self.countryColor

        if let path = self as? SVGPath {
            path.fill = fillColor
        } else {
            (self as? SVGGroup)?.contents
                .compactMap { $0 as? SVGPath }
                .forEach { $0.fill = fillColor }
        }
    }

    func borders(hidden: Bool) {
        let stroke = SVGStroke(fill: hidden ? Self.countryColor : Self.borderColor, width: 0.1)
        if let path = self as? SVGPath {
            path.stroke = stroke
        } else {
            (self as? SVGGroup)?.contents
                .compactMap { $0 as? SVGPath }
                .forEach { $0.stroke = stroke }
        }
    }
}

extension SVGView {
    func node(code: String) -> SVGNode? {
        svg?.node(code: code)
    }
}
