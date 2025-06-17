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

    public extension View {
        private static func dashStroke(lineWidth: CGFloat) -> StrokeStyle {
            StrokeStyle(
                lineWidth: lineWidth,
                lineCap: .square,
                lineJoin: .miter,
                dash: [.themeSpacing8]
            )
        }

        func themeBorder(
            style: AppTheme.Style = .weak,
            dashed: Bool = false,
            lineWidth: CGFloat = 1,
            cornerRadius: AppTheme.CornerRadius
        ) -> some View {
            let rectangle = RoundedRectangle(cornerRadius: cornerRadius.rawValue)
            let strokeStyle = dashed ? Self.dashStroke(lineWidth: lineWidth) : StrokeStyle(lineWidth: lineWidth)
            let stroke = rectangle
                .stroke(Color(.border, style), style: strokeStyle)
                .padding(dashed ? 1 : 0)
            return clipShape(rectangle)
                .overlay(stroke)
        }

        func clipRectangle(cornerRadius: AppTheme.CornerRadius) -> some View {
            let rectangle = RoundedRectangle(cornerRadius: cornerRadius.rawValue)
            return clipShape(rectangle)
        }

        func frame(_ size: AppTheme.IconSize) -> some View {
            frame(width: size.width, height: size.height)
        }

        func frame(_ size: CGSize) -> some View {
            frame(width: size.width, height: size.height)
        }
    }
#endif
