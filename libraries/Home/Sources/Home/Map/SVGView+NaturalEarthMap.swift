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
struct MapRenderView: View {
    let highlightedCountryCode: String?

    var body: some View {
        SVGView.makeMapView(highlightingCountryWithCode: highlightedCountryCode)
    }
}

@MainActor extension SVGView {
    typealias CountryCodeSVGTuple = (highlightedCountryCode: String?, svg: SVGNode)

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
    private static func makeSVG() -> SVGNode {
        log.info("Parsing map SVG...")
        guard let node = SVGParser.parse(xml: xmlMap) else {
            fatalError("Failed to parse map svg from xml")
        }
        return node
    }

    private static func getCachedMapViewOrCreateEmptyMap() -> CountryCodeSVGTuple {
        return cachedMapTuple ?? (nil, makeSVG())
    }

    /// `SVGNodes` are reference types, and it's not trivial to add support for creating deep copies.
    /// Let's reuse the existing parsed SVG and adjust the highlighted country instead.
    static func makeMapView(highlightingCountryWithCode countryCode: String? = nil) -> SVGView {
        guard let lowercaseCountryCode = countryCode?.lowercased() else {
            return idleMapView
        }

        let previousMapTuple = getCachedMapViewOrCreateEmptyMap()

        // If we're highlighting the same country, return cached svg
        if previousMapTuple.highlightedCountryCode == lowercaseCountryCode {
            log.debug("Returning cached map view for code: \(lowercaseCountryCode)")
            return SVGView(svg: previousMapTuple.svg)
        }

        let currentSVG: SVGNode

        if let previousCountryCode = previousMapTuple.highlightedCountryCode {
            // if we removed borders last time, start off with a plain svg
            if CountriesCoordinates.disputedCountries[previousCountryCode] != nil {
                currentSVG = makeSVG()
                log.debug("previous country \(previousCountryCode), using new map")
            } else {
                currentSVG = previousMapTuple.svg
                // Take the previous node and de-highlight it
                let previousNode = currentSVG.node(code: previousCountryCode)
                log.debug("Removing highlight from previous country: \(previousCountryCode)")
                previousNode?.fill(highlighted: false)
            }
        } else {
            currentSVG = idleMapSVG
            log.debug("no previous country, using new map")
        }

        guard let newNode = currentSVG.node(code: lowercaseCountryCode) else {
            log.error("Failed to find new node to highlight")
            return idleMapView
        }
        if let codes = CountriesCoordinates.disputedCountries[lowercaseCountryCode] {
            log.debug("Hiding new country borders: \(lowercaseCountryCode)")
            newNode.hideBorders()
            codes.forEach { currentSVG.node(code: $0)?.hideBorders() }
        } else {
            log.debug("Highlighting new country: \(lowercaseCountryCode)")
            newNode.fill(highlighted: true)
        }

        cachedMapTuple = (highlightedCountryCode: lowercaseCountryCode, currentSVG)
        return SVGView(svg: currentSVG)
    }

    private static let idleMapSVG = makeSVG()

    /// Optimization: cache the disconnected map view in memory
    static let idleMapView: SVGView = SVGView(svg: idleMapSVG)

    /// Optimization: cache last map so we don't have to re-render the map when switching tabs
    private static var cachedMapTuple: CountryCodeSVGTuple?

    static let mapBounds: CGRect = idleMapSVG.bounds()
}

extension SVGNode {
    private static let highlightedCountryColor = SVGColor(hex: "0x4A4658")
    private static let countryColor = SVGColor(hex: "0x292733")

    func node(code: String) -> SVGNode? {
        getNode(byId: code + "x")
        ?? getNode(byId: code) // add "x" so that by default we only consider mainland of each country
    }

    func fill(highlighted: Bool) {
        let fillColor = highlighted ? Self.highlightedCountryColor : Self.countryColor

        if let path = self as? SVGPath {
            path.fill = fillColor
        } else {
            for node in (self as? SVGGroup)?.contents ?? [] {
                (node as? SVGPath)?.fill = fillColor
            }
        }
    }

    func hideBorders() {
        let stroke = SVGStroke(fill: Self.countryColor, width: 0.5)
        if let path = self as? SVGPath {
            path.stroke = stroke
        } else {
            for node in (self as? SVGGroup)?.contents ?? [] {
                (node as? SVGPath)?.stroke = stroke
            }
        }
    }
}

extension SVGView {
    func node(code: String) -> SVGNode? {
        svg?.node(code: code)
    }
}
