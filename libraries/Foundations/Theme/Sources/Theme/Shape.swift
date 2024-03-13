//
//  Created on 28/02/2024.
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

#if canImport(SwiftUI)
import SwiftUI

extension Shape {
    /// Stroke and fill the shape in one single modifier.
    ///
    /// From: https://www.swiftbysundell.com/articles/stroking-and-filling-a-swiftui-shape-at-the-same-time/
    /// - Parameters:
    ///   - strokeContent: The color or gradient with which to stroke this shape.
    ///   - lineWidth: The width of the stroke that outlines this shape.
    ///   - fillContent: The style options that determine how the fill renders.
    /// - Returns: A stroked and filled shape.
    public func style<S: ShapeStyle, F: ShapeStyle>(
        withStroke strokeContent: S,
        lineWidth: CGFloat = 1,
        fill fillContent: F
    ) -> some View {
        stroke(strokeContent, lineWidth: lineWidth).background(fill(fillContent))
    }
}
#endif
