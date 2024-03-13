//
//  Created on 20/04/2023.
//
//  Copyright (c) 2023 Proton AG
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

extension View {
    public func themeBorder(color: Color,
                            lineWidth: CGFloat,
                            cornerRadius: AppTheme.CornerRadius) -> some View {
        let rectangle = RoundedRectangle(cornerRadius: cornerRadius.rawValue)
        return self
            .clipShape(rectangle)
            .overlay(rectangle.stroke(color, lineWidth: lineWidth))
    }

    public func clipRectangle(cornerRadius: AppTheme.CornerRadius) -> some View {
        let rectangle = RoundedRectangle(cornerRadius: cornerRadius.rawValue)
        return self.clipShape(rectangle)
    }

    public func frame(_ size: AppTheme.IconSize) -> some View {
        return frame(width: size.width, height: size.height)
    }
}
#endif
