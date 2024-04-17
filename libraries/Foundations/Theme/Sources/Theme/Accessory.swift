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
import var ProtonCoreUIFoundations.IconProvider

public struct Accessory: View {
    private let style: Style
    private let size: Size

    public init(style: Style, size: Size = .regular) {
        self.style = style
        self.size = size
    }

    public var body: some View {
        style.image?
            .resizable().frame(.square(style.iconSize * size.modifier))
            .flipsForRightToLeftLayoutDirection(true)
            .foregroundColor(style.color)
    }

    public enum Size {
        case regular
        case large

        var modifier: CGFloat {
            switch self {
            case .regular: return 1.0
            case .large: return 1.5
            }
        }
    }

    public enum Style {

        @ScaledMetric private static var radius: CGFloat = .themeRadius16
        @ScaledMetric private static var square: CGFloat = .themeSpacing24

        case disclosure
        case externalLink
        case checkmark(isActive: Bool)
        case none

        var image: Image? {
            switch self {
            case .disclosure:
                return IconProvider.chevronRight
            case .externalLink:
                return IconProvider.arrowOutSquare
            case .checkmark(let isActive):
                return isActive ? IconProvider.checkmarkCircleFilled : IconProvider.emptyCircle
            case .none:
                return nil
            }
        }

        var color: Color? {
            switch self {
            case .checkmark(let isActive):
                return .init(.icon, isActive ? [.interactive, .active] : .weak)
            default:
                return .init(.icon, .weak)
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .disclosure:
                return Self.square
            case .externalLink:
                return Self.square
            case .checkmark:
                return Self.radius
            case .none:
                return Self.radius
            }
        }
    }

    public static var none: Accessory {
        Accessory(style: .none)
    }

    public static func checkmark(isActive: Bool) -> Accessory {
        Accessory(style: .checkmark(isActive: isActive), size: .large)
    }

    public static var disclosure: Accessory {
        Accessory(style: .disclosure)
    }

    public static var externalLink: Accessory {
        Accessory(style: .externalLink)
    }
}

@available(macOS 12.0, *)
struct Accessory_Previews: PreviewProvider {

    struct Cell: View {
        let title: String
        let accessory: Accessory

        var body: some View {
            HStack {
                Text(title)
                Spacer()
                accessory
            }
        }
    }

    static var previews: some View {
        List {
            Section("Static Accessories") {
                Cell(title: "Drillable Item", accessory: .disclosure)
                Cell(title: "Link", accessory: .externalLink)
                Cell(title: "Other", accessory: .none)
            }
            Section("Checkmarks") {
                Cell(title: "Not Checked", accessory: .checkmark(isActive: false))
                Cell(title: "Checked", accessory: .checkmark(isActive: true))
                Cell(title: "Another Not Checked", accessory: .checkmark(isActive: false))
            }
        }
    }
}
