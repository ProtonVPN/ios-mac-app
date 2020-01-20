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

import Cocoa

extension NSImage {
    
    func resize(newWidth w: Int, newHeight h: Int) -> NSImage {
        let destSize = NSSize(width: CGFloat(w), height: CGFloat(h))
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        self.draw(in: NSRect(x: 0, y: 0, width: destSize.width, height: destSize.height),
                  from: NSRect(x: 0, y: 0, width: self.size.width, height: self.size.height),
                  operation: NSCompositingOperation.sourceOver,
                  fraction: CGFloat(1))
        newImage.unlockFocus()
        newImage.size = destSize
        return NSImage(data: newImage.tiffRepresentation!)!
    }
    
    func colored(_ color: NSColor) -> NSImage {
        guard let colored = copy() as? NSImage else { return self }
        
        colored.lockFocus()
        color.set()
        
        let imageRect = NSRect(origin: NSPoint.zero, size: size)
        imageRect.fill(using: .sourceAtop)
        
        colored.unlockFocus()
        
        return colored
    }
}
