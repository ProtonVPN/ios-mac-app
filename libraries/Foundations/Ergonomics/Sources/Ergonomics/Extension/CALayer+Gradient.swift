//
//  Created on 22/01/2024.
//
//  Copyright (c) 2024 Proton AG
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
import QuartzCore
#if os(iOS)
import UIKit

public extension CALayer {
    private static let kLayerNameGradientBorder = "GradientBorderLayer"

    func gradientBorder(
        width: CGFloat = 1,
        colors: [UIColor],
        startPoint: CGPoint = .CoordinateSpace.left,
        endPoint: CGPoint = .CoordinateSpace.right,
        andRoundCornersWithRadius cornerRadius: CGFloat = 0
    ) {
        let existingBorder = gradientBorderLayer()
        existingBorder?.removeFromSuperlayer()
        let border = CAGradientLayer()
        border.name = Self.kLayerNameGradientBorder
        border.frame = CGRect(x: bounds.origin.x,
                              y: bounds.origin.y,
                              width: bounds.size.width + width,
                              height: bounds.size.height + width)
        border.colors = colors.map(\.cgColor)
        border.startPoint = startPoint
        border.endPoint = endPoint

        let mask = CAShapeLayer()
        let maskRect = CGRect(x: bounds.origin.x + width / 2,
                              y: bounds.origin.y + width / 2,
                              width: bounds.size.width - width,
                              height: bounds.size.height - width)
        mask.path = UIBezierPath(roundedRect: maskRect,
                                 cornerRadius: cornerRadius).cgPath
        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.white.cgColor
        mask.lineWidth = width

        border.mask = mask

        addSublayer(border)
    }

    private func gradientBorderLayer() -> CAGradientLayer? {
        let borderLayers = sublayers?.filter {
            $0.name == Self.kLayerNameGradientBorder
        }
        if borderLayers?.count ?? 0 > 1 {
            fatalError()
        }
        return borderLayers?.first as? CAGradientLayer
    }
}

#endif
