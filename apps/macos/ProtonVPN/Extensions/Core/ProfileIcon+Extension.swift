//
//  ProfileIcon+Extension.swift
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

import Foundation
import vpncore

extension ProfileIcon {
    
    func attributedAttachment(width: Int = 12) -> NSAttributedString {
        switch self {
        case .image(let imageName):
            return NSAttributedString.imageAttachment(named: imageName, width: width, height: width) ?? NSAttributedString(string: "")
        case .circle(let color):
            let profileCircle = ProfileCircle(frame: CGRect(x: 0, y: 0, width: width, height: width))
            profileCircle.profileColor = NSColor(rgbHex: color)
            let data = profileCircle.dataWithPDF(inside: profileCircle.bounds)
            let image = NSImage(data: data)
            let attachmentCell = NSTextAttachmentCell(imageCell: image)
            let attachment = NSTextAttachment()
            attachment.attachmentCell = attachmentCell
            return NSAttributedString(attachment: attachment)
        }
    }
}
