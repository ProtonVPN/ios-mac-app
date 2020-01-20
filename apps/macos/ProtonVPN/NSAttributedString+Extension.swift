//
//  NSAttributedString+Extension.swift
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
import vpncore

extension NSAttributedString {
    
    static func concatenate(_ strings: NSAttributedString...) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString()
        strings.forEach { mutableAttributedString.append($0) }
        return mutableAttributedString
    }
    
    static func imageAttachment(named name: String, width: Int? = nil, height: Int? = nil, colored color: NSColor? = nil) -> NSAttributedString? {
        guard var image = NSImage(named: NSImage.Name(name.lowercased())) else {
            PMLog.D("Could not obtain image named \(name) for text attachment.", level: .debug)
            return nil
        }
        
        if let color = color {
            image = image.colored(color)
        }
        
        let newWidth = width != nil ? width! : Int(image.size.width)
        let newHeight = height != nil ? height! : Int(image.size.height)
        image = image.resize(newWidth: newWidth, newHeight: newHeight)
        let attachmentCell = NSTextAttachmentCell(imageCell: image)
        let attachment = NSTextAttachment()
        attachment.attachmentCell = attachmentCell
        return NSAttributedString(attachment: attachment)
    }
}
