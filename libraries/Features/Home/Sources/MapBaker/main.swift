//
//  Created on 19/06/2026.
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

// MapBaker — converts the source world-map SVG into the compact `world-globe.bin` consumed at runtime.
//
// Usage (run from the Home package directory):
//
//     swift run MapBaker [input.svg] [output.bin]
//
// Defaults point at the in-repo asset and resource, so a plain `swift run MapBaker` re-bakes after the
// SVG is updated. Commit the regenerated `world-globe.bin` alongside the SVG change.

import Foundation
import MapModel
import SVGView

let defaultInput = "Sources/HomeShared/Resources/BlankMap-World.svg"
let defaultOutput = "Sources/HomeShared/Resources/world-globe.bin"

let arguments = CommandLine.arguments
let inputURL = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : defaultInput)
let outputURL = URL(fileURLWithPath: arguments.count > 2 ? arguments[2] : defaultOutput)

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("MapBaker error: \(message)\n".utf8))
    exit(1)
}

/// Swap the SVG's embedded `<style>` for `MapCSS` so country fills/strokes resolve to the app's colours.
///
/// Done as a string substitution (rather than mutating the parsed XML) because Foundation also exports
/// an `XMLElement` type that collides with SVGView's, and the `SVGView` module name collides with its
/// own `SVGView` type — making the parsed-node types awkward to reference by name here.
func applyMapCSS(to svg: String) -> String {
    let pattern = "<style[^>]*>.*?</style>"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
        return svg
    }
    let range = NSRange(svg.startIndex..., in: svg)
    guard regex.firstMatch(in: svg, options: [], range: range) != nil else {
        print("MapBaker: warning — no <style> element found; using the SVG's own colours")
        return svg
    }
    let replacement = "<style type=\"text/css\">\n\(MapCSS.css)\n</style>"
    let template = NSRegularExpression.escapedTemplate(for: replacement)
    return regex.stringByReplacingMatches(in: svg, options: [], range: range, withTemplate: template)
}

guard FileManager.default.fileExists(atPath: inputURL.path) else {
    fail("input SVG not found at \(inputURL.path) (run from the Home package directory)")
}

print("MapBaker: reading \(inputURL.path)")
guard let original = try? String(contentsOf: inputURL, encoding: .utf8) else {
    fail("failed to read \(inputURL.lastPathComponent)")
}

guard let root = SVGParser.parse(string: applyMapCSS(to: original)) else {
    fail("failed to parse SVG geometry")
}

print("MapBaker: extracting globe geometry…")
let globe = GlobeExtractor.extract(from: root)
let globeData = MapGlobeCodec.encode(globe)

do {
    try globeData.write(to: outputURL)
} catch {
    fail("failed to write \(outputURL.path): \(error)")
}

// Round-trip the encoded bytes so a broken format fails the bake, not the app at launch.
do {
    _ = try MapGlobeCodec.decode(globeData)
} catch {
    fail("globe binary failed to decode: \(error)")
}

let globeSizeKB = Double(globeData.count) / 1024
print("""
MapBaker: wrote \(outputURL.path)
  fill vertices:   \(globe.fillVertices.count)
  fill indices:    \(globe.fillIndices.count) (\(globe.fillIndices.count / 3) triangles)
  draw units:      \(globe.drawOrder.count)
  border segments: \(globe.borderSegments.count)
  countries:       \(globe.countries.count)
  file size:       \(String(format: "%.1f", globeSizeKB)) KB
""")
