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
import Cocoa
import AppKit

public extension NSImage {
    func resize(newWidth width: Int, newHeight height: Int) -> NSImage {
        resizeWhilePreservingRatio(newWidth: CGFloat(width), newHeight: CGFloat(height))
    }

    func resizeWhilePreservingRatio(newWidth width: CGFloat? = nil, newHeight height: CGFloat? = nil) -> NSImage {
        let w: CGFloat
        let h: CGFloat
        if let width, let height {
            h = height
            w = width
        } else if width == nil, let height {
            h = height
            w = (h / size.height) * size.width
        } else if height == nil, let width {
            w = width
            h = (w / size.width) * size.height
        } else {
            return self
        }
        return resize(w: w, h: h)
    }

    private func resize(w: CGFloat, h: CGFloat) -> NSImage {
        let destSize = NSSize(width: w, height: h)
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        self.draw(in: NSRect(x: 0, y: 0, width: destSize.width, height: destSize.height),
                  from: NSRect(x: 0, y: 0, width: self.size.width, height: self.size.height),
                  operation: NSCompositingOperation.sourceOver,
                  fraction: CGFloat(1))
        newImage.unlockFocus()
        newImage.size = destSize
        let newResized = NSImage(data: newImage.tiffRepresentation!)!
        newResized.isTemplate = isTemplate
        return newResized
    }
    
    func colored(_ color: NSColor) -> NSImage {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return self
        }
        
        return NSImage(size: size, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            color.set()
            context.clip(to: bounds, mask: cgImage)
            context.fill(bounds)
            return true
        }
    }

    func grayOut() -> NSImage? {
        guard let image = cgImage else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: image)

        guard let greyScale = bitmap.converting(to: .genericGray, renderingIntent: .default) else {
            return nil
        }

        let greyImage = NSImage(size: greyScale.size)
        greyImage.addRepresentation(greyScale)
        return greyImage
    }
}

public extension NSImage {
    var cgImage: CGImage? {
        var rect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.size)
        return self.cgImage(forProposedRect: &rect, context: NSGraphicsContext.current, hints: nil)
    }
}
#endif
