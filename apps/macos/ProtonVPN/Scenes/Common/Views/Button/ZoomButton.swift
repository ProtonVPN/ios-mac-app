//
//  ZoomButton.swift
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
import LegacyCommon
import Theme
import Ergonomics

enum ZoomType {
    case `in`
    case out
}

class ZoomButton: HoverDetectionButton {
    
    let zoomType: ZoomType
    let imageView = NSImageView()
    
    override var frame: NSRect {
        didSet {
            needsDisplay = true
        }
    }
    
    init(type zoomType: ZoomType) {
        self.zoomType = zoomType

        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))

        let image = zoomType == .in ? AppTheme.Icon.plus : AppTheme.Icon.minus
        imageView.image = self.colorImage(image)
        imageView.isHidden = false

        isTransparent = true
        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let cornerRadius: CGFloat = 4
        let lineWidth: CGFloat = 1
        let plusButtonFrame = CGRect(x: 0.5, y: 0.5, width: bounds.width - 1, height: bounds.height - 1)

        context.setLineWidth(lineWidth)
        context.setStrokeColor(self.cgColor(.border))
        context.setFillColor(self.cgColor(.background))

        let path = CGMutablePath()
        path.addRoundedRectangle(plusButtonFrame, cornerRadius: cornerRadius)

        context.addPath(path)
        context.drawPath(using: .fillStroke)

        let margin: CGFloat = 6
        let imageFrame = CGRect(x: margin / 2, y: margin / 2,
                                width: bounds.width - margin,
                                height: bounds.width - margin)
        imageView.frame = imageFrame
        imageView.needsDisplay = true
    }
    
}

extension ZoomButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .icon, .border:
            return .normal
        case .background:
            return .transparent + (isHovered ? .hovered : [])
        default:
            break
        }

        log.assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
