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

import CoreGraphics
import Foundation
import simd
import SVGView

/// Walks the source SVG tree and flattens it into render-ready paths, so the expensive XML walk and
/// Bezier flattening happen once, offline, rather than in the app. Feeds `GlobeExtractor`.
enum MapExtractor {
    private enum Constants {
        /// Opacity at or below this is treated as hidden. The ocean, small-territory circles, and the
        /// limited-recognition overlays are authored with zero opacity.
        ///
        /// Note that SVGView resolves a CSS `opacity: 0` onto the fill and stroke colors' alpha rather
        /// than `node.opacity`, so this node-level check rarely fires. `hiddenAlphaThreshold` below is
        /// what actually culls the ocean and the duplicate overlay layers.
        static let hiddenOpacityThreshold: Double = 0.01
        /// A resolved fill or stroke color at or below this alpha contributes nothing and is dropped.
        static let hiddenAlphaThreshold: Float = 0.01
        /// Recursion cap on curve subdivision, bounding a pathological curve at 2^18 segments. Real map
        /// curves flatten within a handful of levels.
        static let maxSubdivisionDepth = 18
    }

    private enum Dimensions {
        /// Map-space tolerance for subdividing Bezier curves. The source is already dense polylines, so
        /// this is rarely hit. Kept small so extreme zoom never reveals facets.
        static let flatness: CGFloat = 0.15
    }

    /// Walks the SVG once and returns the flattened paths for `GlobeExtractor`.
    static func collectPaths(from root: SVGNode) -> [ExtractedPath] {
        var paths: [ExtractedPath] = []
        walk(root, transform: .identity, opacity: 1, ancestorIDs: [], into: &paths)
        return paths
    }

    // MARK: Tree walk

    final class ExtractedPath {
        let ancestorIDs: [String]
        let rings: [Ring]
        let fillColor: SIMD4<Float>?
        let strokeColor: SIMD4<Float>?
        let strokeHalfWidth: Float
        let pointBounds: CGRect

        init(
            ancestorIDs: [String],
            rings: [Ring],
            fillColor: SIMD4<Float>?,
            strokeColor: SIMD4<Float>?,
            strokeHalfWidth: Float,
            pointBounds: CGRect
        ) {
            self.ancestorIDs = ancestorIDs
            self.rings = rings
            self.fillColor = fillColor
            self.strokeColor = strokeColor
            self.strokeHalfWidth = strokeHalfWidth
            self.pointBounds = pointBounds
        }
    }

    struct Ring {
        var points: [SIMD2<Float>]
        var closed: Bool
    }

    private static func walk(
        _ node: SVGNode,
        transform: CGAffineTransform,
        opacity: Double,
        ancestorIDs: [String],
        into paths: inout [ExtractedPath]
    ) {
        let opacity = opacity * node.opacity
        if opacity <= Constants.hiddenOpacityThreshold { return } // skip the ocean and hidden overlays wholesale

        let worldTransform = node.transform.concatenating(transform)
        var ids = ancestorIDs
        if let id = node.id, !id.isEmpty { ids.append(id) }

        switch node {
        case let group as SVGGroup:
            for child in group.contents {
                walk(child, transform: worldTransform, opacity: opacity, ancestorIDs: ids, into: &paths)
            }
        case let path as SVGPath:
            if let extracted = extract(path, transform: worldTransform, ancestorIDs: ids) {
                paths.append(extracted)
            }
        default:
            // The visible world map is entirely <path>; other shape types around tiny territories are
            // authored opacity:0 and skipped above.
            break
        }
    }

    private static func extract(
        _ path: SVGPath,
        transform: CGAffineTransform,
        ancestorIDs: [String]
    ) -> ExtractedPath? {
        let rings = flatten(path.toBezierPath().cgPath, transform: transform)
        guard !rings.isEmpty else { return nil }

        let fillColor = (path.fill as? SVGColor).map(color(from:)).flatMap(visible)
        var strokeColor: SIMD4<Float>?
        var strokeHalfWidth: Float = 0
        if let stroke = path.stroke, let svgColor = stroke.fill as? SVGColor,
           let resolved = visible(color(from: svgColor)) {
            strokeColor = resolved
            strokeHalfWidth = Float(stroke.width) * 0.5
        }
        guard fillColor != nil || strokeColor != nil else { return nil }

        return ExtractedPath(
            ancestorIDs: ancestorIDs,
            rings: rings,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeHalfWidth: strokeHalfWidth,
            pointBounds: bounds(of: rings)
        )
    }

    // MARK: Helpers

    private static func bounds(of rings: [Ring]) -> CGRect {
        var minX = Float.greatestFiniteMagnitude, minY = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude, maxY = -Float.greatestFiniteMagnitude
        for ring in rings {
            for p in ring.points {
                minX = min(minX, p.x); minY = min(minY, p.y)
                maxX = max(maxX, p.x); maxY = max(maxY, p.y)
            }
        }
        guard maxX >= minX else { return .zero }
        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX),
            height: CGFloat(maxY - minY)
        )
    }

    static func color(from svg: SVGColor) -> SIMD4<Float> {
        // `svg.r/g/b` and `svg.opacity` are the public accessors (`t`/`a` are internal to SVGView).
        SIMD4<Float>(Float(svg.r) / 255, Float(svg.g) / 255, Float(svg.b) / 255, Float(svg.opacity))
    }

    /// Returns the color only if it is actually visible; near-zero alpha is treated as absent.
    private static func visible(_ color: SIMD4<Float>) -> SIMD4<Float>? {
        color.w > Constants.hiddenAlphaThreshold ? color : nil
    }

    // MARK: CGPath flattening

    private static func flatten(_ path: CGPath, transform: CGAffineTransform) -> [Ring] {
        var rings: [Ring] = []
        var current: [SIMD2<Float>] = []
        var closed = false
        var start = CGPoint.zero
        var last = CGPoint.zero
        let identity = transform.isIdentity

        func point(_ p: CGPoint) -> CGPoint {
            identity ? p : p.applying(transform)
        }
        func push(_ p: CGPoint) {
            current.append(SIMD2<Float>(Float(p.x), Float(p.y)))
        }
        func emit() {
            if current.count >= 2 { rings.append(Ring(points: current, closed: closed)) }
            current = []
            closed = false
        }

        path.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            switch element.type {
            case .moveToPoint:
                emit()
                last = point(element.points[0]); start = last
                push(last)
            case .addLineToPoint:
                last = point(element.points[0]); push(last)
            case .addQuadCurveToPoint:
                let control = point(element.points[0])
                let end = point(element.points[1])
                subdivideQuad(from: last, control: control, to: end, push: push)
                last = end
            case .addCurveToPoint:
                let c1 = point(element.points[0])
                let c2 = point(element.points[1])
                let end = point(element.points[2])
                subdivideCubic(from: last, control1: c1, control2: c2, to: end, push: push)
                last = end
            case .closeSubpath:
                closed = true; emit(); last = start
            @unknown default:
                break
            }
        }
        emit()
        return rings
    }

    private static func subdivideCubic(
        from p0: CGPoint,
        control1 p1: CGPoint,
        control2 p2: CGPoint,
        to p3: CGPoint,
        depth: Int = 0,
        push: (CGPoint) -> Void
    ) {
        if depth >= Constants.maxSubdivisionDepth || cubicIsFlat(p0, p1, p2, p3) {
            push(p3)
            return
        }
        let p01 = mid(p0, p1), p12 = mid(p1, p2), p23 = mid(p2, p3)
        let p012 = mid(p01, p12), p123 = mid(p12, p23)
        let m = mid(p012, p123)
        subdivideCubic(from: p0, control1: p01, control2: p012, to: m, depth: depth + 1, push: push)
        subdivideCubic(from: m, control1: p123, control2: p23, to: p3, depth: depth + 1, push: push)
    }

    private static func subdivideQuad(
        from p0: CGPoint,
        control p1: CGPoint,
        to p2: CGPoint,
        depth: Int = 0,
        push: (CGPoint) -> Void
    ) {
        if depth >= Constants.maxSubdivisionDepth || quadIsFlat(p0, p1, p2) {
            push(p2)
            return
        }
        let p01 = mid(p0, p1), p12 = mid(p1, p2)
        let m = mid(p01, p12)
        subdivideQuad(from: p0, control: p01, to: m, depth: depth + 1, push: push)
        subdivideQuad(from: m, control: p12, to: p2, depth: depth + 1, push: push)
    }

    private static func cubicIsFlat(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> Bool {
        max(distanceToLine(p1, a: p0, b: p3), distanceToLine(p2, a: p0, b: p3)) <= Dimensions.flatness
    }

    private static func quadIsFlat(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint) -> Bool {
        distanceToLine(p1, a: p0, b: p2) <= Dimensions.flatness
    }

    private static func distanceToLine(_ p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared < 1e-12 { return hypot(p.x - a.x, p.y - a.y) }
        return abs((p.x - a.x) * dy - (p.y - a.y) * dx) / sqrt(lengthSquared)
    }

    private static func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }
}
