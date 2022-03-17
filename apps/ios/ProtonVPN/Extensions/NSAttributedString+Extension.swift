//
//  NSAttributedString+Extension.swift
//  ProtonVPN - Created on 01.07.19.
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

import UIKit
import vpncore

extension NSAttributedString {
    
    static func concatenate(_ strings: NSAttributedString...) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString()
        strings.forEach { mutableAttributedString.append($0) }
        return mutableAttributedString
    }

    static func imageAttachment(named name: String, width: CGFloat? = nil, height: CGFloat? = nil) -> NSAttributedString? {
        imageAttachment(image: UIImage(named: name.lowercased()), width: width, height: height)
    }
    
    static func imageAttachment(image: UIImage?, width: CGFloat? = nil, height: CGFloat? = nil) -> NSAttributedString? {
        guard let image = image else {
            log.debug("Could not obtain image named for text attachment", category: .app)
            return nil
        }

        let attachment = NSTextAttachment()
        if let width = width, let height = height {
            attachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        }

        attachment.image = image
        return NSAttributedString(attachment: attachment)
    }

    static func imageAttachment(named name: String, width: CGFloat? = nil, height: CGFloat? = nil) -> NSAttributedString? {
        guard let image = UIImage(named: name.lowercased()) else {
            log.debug("Could not obtain image named for text attachment", category: .app, metadata: ["name": "\(name)"])
            return nil
        }
        return imageAttachment(image: image, width: width, height: height)
    }
}
