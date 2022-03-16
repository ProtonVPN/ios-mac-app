//
//  Created on 2022-03-13.
//
//  Copyright (c) 2022 Proton AG
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
import Cocoa

extension NSImage {
    func colored(context: AppTheme.Context = .icon, _ style: AppTheme.Style = .normal) -> NSImage {
        self.colored(.color(context, style))
    }

    func asAttachment(context: AppTheme.Context = .icon, style: AppTheme.Style? = nil, size: AppTheme.IconSize = .default) -> NSAttributedString {
        var resultingImage = self
        if let style = style {
            resultingImage = self.colored(context: context, style)
        }

        switch size {
        case .square(let size):
            resultingImage = resultingImage.resize(newWidth: size, newHeight: size)
        case let .rect(width, height):
            resultingImage = resultingImage.resize(newWidth: width, newHeight: height)
        case .default:
            break
        }

        let attachmentCell = NSTextAttachmentCell(imageCell: resultingImage)
        let attachment = NSTextAttachment()
        attachment.attachmentCell = attachmentCell
        return NSAttributedString(attachment: attachment)
    }
}

extension CustomStyleContext {
    func colorImage(_ image: NSImage, context: AppTheme.Context = .icon) -> NSImage {
        image.colored(context: context, self.customStyle(context: context))
    }
}
