//
//  Created on 2022-04-08.
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
import CoreGraphics

extension CGMutablePath {
    func addRoundedRectangle(_ rect: CGRect, cornerRadius: CGFloat) {
        self.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        self.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius))
        self.addArc(center: CGPoint(x: rect.minX + cornerRadius,
                                    y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .pi, endAngle: .pi / 2,
                    clockwise: true)
        self.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY))
        self.addArc(center: CGPoint(x: rect.maxX - cornerRadius,
                                    y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .pi / 2, endAngle: 0,
                    clockwise: true)
        self.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius))
        self.addArc(center: CGPoint(x: rect.maxX - cornerRadius,
                                    y: rect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: 0, endAngle: .pi * 3 / 2,
                    clockwise: true)
        self.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        self.addArc(center: CGPoint(x: rect.minX + cornerRadius,
                                    y: rect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: .pi * 3 / 2, endAngle: .pi,
                    clockwise: true)
        self.closeSubpath()
    }
}
