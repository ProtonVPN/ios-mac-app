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
    let focusedCountryCode: String?

    var body: some View {
        SVGView.naturalEarthMap(focusedOn: focusedCountryCode)
    }
}

extension SVGView {
    private static func xmlMap() -> XMLElement {
        let url = Bundle.module.url(forResource: "BlankMap-World", withExtension: "svg")!
        let xml = DOMParser.parse(contentsOf: url)!

        let index = xml.contents.firstIndex { node in
            (node as? XMLElement)?.name == "style"
        }
        if let index {
            (xml.contents[index] as? XMLElement)?.contents = [XMLText(text: MapCSS.css)]
        }
        return xml
    }

    static let naturalEarthMap = SVGView(xml: Self.xmlMap())

    static func naturalEarthMap(focusedOn focusedCountryCode: String?) -> Self {
        guard let focusedCountryCode else {
            return naturalEarthMap
        }

        let map = SVGView.naturalEarthMap // copy

        map.node(code: focusedCountryCode.lowercased()).map {
            map.highlight(node: $0)
        }

        return map
    }
}

extension SVGView {
    func node(code: String) -> SVGNode? {
        getNode(byId: code + "x")
        ?? getNode(byId: code) // add "x" so that by default we only consider mainland of each country
    }

    private static let highlightedCountryColor = SVGColor(hex: "0x4A4658")

    func highlight(node: SVGNode) {
        if let path = node as? SVGPath {
            path.fill = Self.highlightedCountryColor
        } else {
            for node in (node as? SVGGroup)?.contents ?? [] {
                (node as? SVGPath)?.fill = Self.highlightedCountryColor
            }
        }
    }
}
