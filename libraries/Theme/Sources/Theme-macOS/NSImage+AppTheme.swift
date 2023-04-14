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
import Theme

public extension NSImage {
    func colored(context: AppTheme.Context = .icon, _ style: AppTheme.Style = .normal) -> NSImage {
        self.colored(.color(context, style))
    }

    func asAttachment(context: AppTheme.Context = .icon, style: AppTheme.Style? = nil, size: AppTheme.IconSize = .default, centeredVerticallyForFont font: NSFont? = nil) -> NSAttributedString {
        var resultingImage = self
        if let style = style {
            resultingImage = self.colored(context: context, style)
        }
        resultingImage = resultingImage.resize(size)

        let attachment = NSTextAttachment()
        attachment.image = resultingImage
        if let font = font {
            let imageY = (font.capHeight - resultingImage.size.height).rounded(.toNearestOrEven) / 2
            attachment.bounds = CGRect(origin: CGPoint(x: 0, y: imageY), size: resultingImage.size)
        }

        return NSAttributedString(attachment: attachment)
    }

    func resize(_ newSize: AppTheme.IconSize) -> NSImage {
        switch newSize {
        case .square(let size):
            return self.resize(newWidth: size, newHeight: size)
        case let .rect(width, height):
            return self.resize(newWidth: width, newHeight: height)
        case .default:
            return self
        }
    }
}

public extension CustomStyleContext {
    func colorImage(_ image: NSImage, context: AppTheme.Context = .icon) -> NSImage {
        image.colored(context: context, self.customStyle(context: context))
    }
}
