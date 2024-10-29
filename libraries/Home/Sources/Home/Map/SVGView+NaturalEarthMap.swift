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

struct MapRenderView: View {
    let highlightedCountryCode: String?

    var body: some View {
        SVGView.makeMapView(highlightingCountryWithCode: highlightedCountryCode)
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

    private static func makeSVG() -> SVGNode {
        log.info("Parsing map SVG...")
        guard let node = SVGParser.parse(xml: xmlMap) else {
            log.error("Failed to parse map svg from xml")
            return SVGNode()
        }
        return node
    }

    static func makeMapView(highlightingCountryWithCode countryCode: String? = nil) -> SVGView {
        guard let lowercaseCountryCode = countryCode?.lowercased() else {
            return idleMapView
        }

        if let lastMapView, lastMapView.highlightedCountryCode == lowercaseCountryCode {
            log.info("Returning cached map view for code: \(lowercaseCountryCode)")
            return lastMapView.mapView
        }

        // Parsing is very expensive
        // In the future we could un-highlight the previous country
        // Or add support for deep-copying the svg (non-trivial, probably requires forking SVGView)
        let svg = makeSVG()

        guard let node = svg.node(code: lowercaseCountryCode) else {
            log.error("Failed to find node for code: \(lowercaseCountryCode)")
            return SVGView(svg: makeSVG())
        }
        node.highlight()

        let mapView = SVGView(svg: svg)
        lastMapView = (highlightedCountryCode: lowercaseCountryCode, mapView)

        return mapView
    }

    func node(code: String) -> SVGNode? {
        svg?.node(code: code)
    }

    /// Optimization: cache the disconnected map view in memory
    static let idleMapView: SVGView = SVGView(svg: makeSVG())

    /// Optimization: cache last map so we don't have to re-render the map when switching tabs
    static var lastMapView: (highlightedCountryCode: String, mapView: SVGView)?
}

extension SVGNode {
    private static let highlightedCountryColor = SVGColor(hex: "0x4A4658")

    func node(code: String) -> SVGNode? {
        getNode(byId: code + "x")
        ?? getNode(byId: code) // add "x" so that by default we only consider mainland of each country
    }

    func highlight() {
        if let path = self as? SVGPath {
            path.fill = Self.highlightedCountryColor
        } else {
            for node in (self as? SVGGroup)?.contents ?? [] {
                (node as? SVGPath)?.fill = Self.highlightedCountryColor
            }
        }
    }
}
