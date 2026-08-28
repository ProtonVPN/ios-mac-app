//
//  Created on 28/08/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

#if os(macOS)
    import AppKit
    import SnapshotTesting

    // MARK: - NSView

    public extension Snapshotting where Value == NSView, Format == NSImage {
        /// A pixel-equality snapshot strategy that renders at an explicit scale,
        /// independent of the host machine's screen configuration.
        ///
        /// The stock `Snapshotting<NSView, NSImage>.image` renders through
        /// `bitmapImageRepForCachingDisplay(in:)`, which inherits the backing scale
        /// of the view's window (or the machine's screens for a windowless view).
        /// That makes references recorded on a Retina display 2x while a headless CI
        /// renders 1x, failing with a dimension mismatch. This strategy instead
        /// draws into a bitmap rep whose pixel dimensions are pinned to
        /// `bounds * scale`.
        ///
        /// - Parameters:
        ///   - precision: The percentage of pixels that must match.
        ///   - perceptualPrecision: The percentage a pixel must match the source
        ///     pixel to be considered a match.
        ///   - size: A view size override, in points.
        ///   - scale: Pixels per point of the rendered snapshot. Use `1` to match
        ///     headless CI.
        static func image(
            precision: Float = 1,
            perceptualPrecision: Float = 1,
            size: CGSize? = nil,
            scale: CGFloat = 1
        ) -> Snapshotting {
            Snapshotting<NSImage, NSImage>(
                pathExtension: "png",
                diffing: .fixedScaleImage(precision: precision, perceptualPrecision: perceptualPrecision)
            )
            .pullback { view in
                MainActor.assumeIsolated {
                    let initialFrame = view.frame
                    defer { view.frame = initialFrame }
                    if let size { view.frame.size = size }
                    precondition(
                        view.frame.width > 0 && view.frame.height > 0,
                        "View not renderable to image at size \(view.frame.size)"
                    )
                    view.layoutSubtreeIfNeeded()
                    return renderFixedScale(view: view, scale: scale)
                }
            }
        }
    }

    // MARK: - Rendering

    /// Draws `view` into a bitmap whose pixel dimensions are exactly
    /// `view.bounds * scale`, regardless of any attached screens.
    ///
    /// Rendering goes through `cacheDisplay(in:to:)`, the same machinery as the
    /// stock strategy — only the rep's pixel density is pinned instead of being
    /// derived by `bitmapImageRepForCachingDisplay(in:)`. Note this does not
    /// capture live `WKWebView`/`SCNView`/`SKView` content; the stock strategy
    /// snapshots those separately via a window hard-coded to 2x, so mixing them
    /// with a fixed-scale strategy is not meaningful anyway.
    private func renderFixedScale(view: NSView, scale: CGFloat) -> NSImage {
        let pixelsWide = Int((view.bounds.width * scale).rounded())
        let pixelsHigh = Int((view.bounds.height * scale).rounded())

        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelsWide,
                pixelsHigh: pixelsHigh,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .calibratedRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            preconditionFailure(
                "Could not create bitmap rep at \(pixelsWide)x\(pixelsHigh)"
            )
        }
        // Point size derived from pixel size keeps points-per-pixel exactly `scale`
        // even after integral rounding above.
        rep.size = CGSize(
            width: CGFloat(pixelsWide) / scale,
            height: CGFloat(pixelsHigh) / scale
        )

        view.cacheDisplay(in: view.bounds, to: rep)

        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }

    private extension Diffing where Value == NSImage {
        /// The library's image diffing with one substitution: the serializer that writes reference files.
        ///
        /// The stock `toData` converts through `NSImage.cgImage(forProposedRect: nil, context: nil,
        /// hints: nil)`, and with no context AppKit rasterizes for the machine's screens — on a Retina
        /// display that redraws the pinned 1x rep into a 2x bitmap at encode time, so the recorded file
        /// comes out double-sized and fails on a 1x machine with a dimension mismatch. Verification stays
        /// with the stock compare, which applies the same conversion to both sides on the same machine and
        /// is therefore consistent with itself.
        static func fixedScaleImage(precision: Float, perceptualPrecision: Float) -> Diffing {
            var diffing = Diffing.image(precision: precision, perceptualPrecision: perceptualPrecision)
            diffing.toData = { image in
                guard
                    let rep = image.representations.first as? NSBitmapImageRep,
                    let data = rep.representation(using: .png, properties: [:])
                else {
                    preconditionFailure(
                        "Fixed-scale snapshotting serializes the bitmap rep it rendered; this image has none"
                    )
                }
                return data
            }
            return diffing
        }
    }
#endif
