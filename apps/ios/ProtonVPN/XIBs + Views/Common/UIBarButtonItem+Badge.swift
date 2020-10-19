//
//  UIBarButtonItem+Badge.swift
//  ProtonVPN - Created on 2020-10-12.
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

// Main idea from https://gist.github.com/freedom27/c709923b163e26405f62b799437243f4 comments

private var handle: UInt8 = 0

extension UIBarButtonItem {
    
    private var badgeLayer: CAShapeLayer? {
        if let b: AnyObject = objc_getAssociatedObject(self, &handle) as AnyObject? {
            return b as? CAShapeLayer
        } else {
            return nil
        }
    }

    func addBadge(offset: CGPoint = .zero, color: UIColor = .red, filled: Bool = true) {
        badgeLayer?.removeFromSuperlayer()
        guard let view = self.value(forKey: "view") as? UIView else {
            return
        }

        let badgeSize = UILabel(frame: CGRect(x: 22, y: -5, width: 10, height: 10))
        let x = view.frame.width - badgeSize.frame.width + offset.x
        let badgeFrame = CGRect(origin: CGPoint(x: x, y: offset.y), size: CGSize(width: badgeSize.frame.width, height: badgeSize.frame.height))

        let badge = CAShapeLayer()
        badge.drawRoundedRect(rect: badgeFrame, andColor: color, filled: filled)
        view.layer.addSublayer(badge)

        // Save Badge as UIBarButtonItem property
        objc_setAssociatedObject(self, &handle, badge, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        badge.zPosition = 1000
    }

    func removeBadge() {
        badgeLayer?.removeFromSuperlayer()
    }
    
}

extension CAShapeLayer {
    func drawRoundedRect(rect: CGRect, andColor color: UIColor, filled: Bool) {
        fillColor = filled ? color.cgColor : UIColor.white.cgColor
        strokeColor = color.cgColor
        path = UIBezierPath(roundedRect: rect, cornerRadius: 7).cgPath
    }
}
