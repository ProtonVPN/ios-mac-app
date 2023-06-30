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
    @ScaledMetric private var radius: CGFloat = .themeRadius16

    public init(style: Style) {
        self.style = style
    }

    public var body: some View {
        style.image?
            .resizable().frame(.square(radius))
            .foregroundColor(style.color)
    }

    public enum Style {
        case disclosure
        case externalLink
        case checkmark(isActive: Bool)
        case none

        var image: Image? {
            switch self {
            case .disclosure:
                return Image(asset: Asset.icChevronRight)
            case .externalLink:
                return Image(asset: Asset.icArrowOutSquare)
            case .checkmark(let isActive):
                return Image(asset: isActive ? Asset.icCheckmarkCircleFilled : Asset.icEmptyCircle
)
            case .none:
                return nil
            }
        }

        var color: Color? {
            switch self {
            case .checkmark(let isActive):
                return .init(.icon, isActive ? .interactive : .weak)
            default:
                return .init(.icon, .weak)
            }
        }
    }

    public static var none: Accessory {
        Accessory(style: .none)
    }

    public static func checkmark(isActive: Bool) -> Accessory {
        Accessory(style: .checkmark(isActive: isActive))
    }

    public static var disclosure: Accessory {
        Accessory(style: .disclosure)
    }

    public static var externalLink: Accessory {
        Accessory(style: .externalLink)
    }
}

struct Accessory_Previews: PreviewProvider {

    struct Cell: View {
        let title: String
        let accessoryStyle: Accessory.Style

        var body: some View {
            HStack {
                Text(title)
                Spacer()
                Accessory(style: accessoryStyle)
            }
        }
    }

    static var previews: some View {
        List {
            Section("Static Accessories") {
                Cell(title: "Drillable Item", accessoryStyle: .disclosure)
                Cell(title: "Link", accessoryStyle: .externalLink)
                Cell(title: "Other", accessoryStyle: .none)
            }
            Section("Checkmarks") {
                Cell(title: "Not Checked", accessoryStyle: .checkmark(isActive: false))
                Cell(title: "Checked", accessoryStyle: .checkmark(isActive: true))
                Cell(title: "Another Not Checked", accessoryStyle: .checkmark(isActive: false))
            }
        }
    }
}
