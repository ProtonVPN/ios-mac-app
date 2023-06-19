//
//  Created on 19/06/2023.
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

import SwiftUI

import Theme

public struct Accessory: View {
    private let style: Style
    @ScaledMetric private var radius: CGFloat = 16

    public init(style: Style) {
        self.style = style
    }

    public var body: some View {
        if let asset = style.imageAsset {
            Image(asset: asset)
                .resizable().frame(.square(radius))
                .foregroundColor(Color(.icon, .weak))
        }
    }

    public enum Style {
        case disclosure
        case externalLink
        case none

        var imageAsset: ImageAsset? {
            switch self {
            case .disclosure: return Asset.icChevronRight
            case .externalLink: return Asset.icArrowOutSquare
            case .none: return nil
            }
        }
    }

    public static var none: Self {
        Self.init(style: .none)
    }

    public static var disclosure: Self {
        Self.init(style: .disclosure)
    }

    public static var externalLink: Self {
        Self.init(style: .externalLink)
    }
}
