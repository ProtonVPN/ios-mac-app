//
//  NSImage+Extension.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

#if canImport(Cocoa)
    import AppKit
    import Cocoa
    import Ergonomics

    public extension NSImage {
        // MARK: Resizing

        func resize(newWidth width: Int, newHeight height: Int) -> NSImage {
            // Exact resize — intentionally does not preserve aspect ratio.
            resize(w: CGFloat(width), h: CGFloat(height))
        }

        /// Resizes the image. If only one dimension is provided, the other is
        /// derived from the source aspect ratio. Returns `self` unchanged if both
        /// dimensions are nil or the image has no drawable size.
        func resizeWhilePreservingRatio(newWidth width: CGFloat? = nil, newHeight height: CGFloat? = nil) -> NSImage {
            guard size.width > 0, size.height > 0 else { return self }

            let w: CGFloat
            let h: CGFloat
            switch (width, height) {
            case let (width?, height?):
                w = width
                h = height
            case let (nil, height?):
                h = height
                w = (h / size.height) * size.width
            case let (width?, nil):
                w = width
                h = (w / size.width) * size.height
            case (nil, nil):
                return self
            }
            return resize(w: w, h: h)
        }

        private func resize(w: CGFloat, h: CGFloat) -> NSImage {
            guard w > 0, h > 0, size.width > 0, size.height > 0,
                  let resized = rasterized(pointSize: NSSize(width: w, height: h), drawing: { bounds in
                      self.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
                  })
            else { return self }

            resized.isTemplate = isTemplate
            return resized
        }

        // MARK: Tinting

        /// Returns a copy of the image tinted with `color`, rendered in the dark
        /// appearance. The result is a plain (non-template) image, since a tinted
        /// image should no longer be recolored by AppKit.
        func colored(_ color: NSColor) -> NSImage {
            guard size.width > 0, size.height > 0,
                  let colored = rasterized(pointSize: size, drawing: { bounds in
                      DarkAppearance {
                          color.set()
                          bounds.fill()
                          self.draw(in: bounds, from: .zero, operation: .destinationIn, fraction: 1)
                      }
                  })
            else { return self }

            return colored
        }

        // MARK: CGImage access

        /// The image rasterized as a `CGImage`, or nil if it cannot be rendered.
        /// Since the transforms above are bitmap-backed, this returns the existing
        /// bitmap rather than triggering a context-dependent rasterization.
        var cgImage: CGImage? {
            var rect = NSRect(origin: .zero, size: size)
            return cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }

        // MARK: Rasterization

        /// Pixels per point for eagerly rasterized images. Fixed at 2x: crisp on
        /// Retina displays and downsampled cleanly on 1x, independent of which
        /// screen is main at call time.
        private static let rasterizationScale: CGFloat = 2

        /// Draws `drawing` once into a bitmap of `pointSize` points at
        /// `rasterizationScale`, and returns an image backed by that bitmap.
        /// Eager and deterministic: no handler is retained, `self` is not captured
        /// beyond this call, and later draws blit the cached bitmap.
        private func rasterized(pointSize: NSSize, drawing: (NSRect) -> Void) -> NSImage? {
            guard let rep = bitmapRepresentation(pointSize: pointSize, drawing: drawing) else {
                return nil
            }
            let image = NSImage(size: pointSize)
            image.addRepresentation(rep)
            return image
        }

        private func bitmapRepresentation(pointSize: NSSize, drawing: (NSRect) -> Void) -> NSBitmapImageRep? {
            let scale = Self.rasterizationScale
            guard pointSize.width > 0, pointSize.height > 0,
                  let rep = NSBitmapImageRep(
                      bitmapDataPlanes: nil,
                      pixelsWide: Int((pointSize.width * scale).rounded()),
                      pixelsHigh: Int((pointSize.height * scale).rounded()),
                      bitsPerSample: 8,
                      samplesPerPixel: 4,
                      hasAlpha: true,
                      isPlanar: false,
                      colorSpaceName: .calibratedRGB,
                      bytesPerRow: 0,
                      bitsPerPixel: 0
                  )
            else { return nil }

            rep.size = pointSize // points; pixels/points ratio encodes the scale

            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
            NSGraphicsContext.current = context
            context.imageInterpolation = .high

            drawing(NSRect(origin: .zero, size: pointSize))
            context.flushGraphics()

            return rep
        }
    }

#endif
