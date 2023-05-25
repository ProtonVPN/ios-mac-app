//
//  Created on 22.05.23.
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

import Foundation
import SwiftUI

public struct FlagAppearance {
    let secureCoreFlagShadowColor: Color
    let secureCoreFlagCurveColor: Color
    let fastestAccentColor: Color
    let fastestBackgroundColor: Color

    public init(
        secureCoreFlagShadowColor: Color,
        secureCoreFlagCurveColor: Color,
        fastestAccentColor: Color,
        fastestBackgroundColor: Color
    ) {
        self.secureCoreFlagShadowColor = secureCoreFlagShadowColor
        self.secureCoreFlagCurveColor = secureCoreFlagCurveColor
        self.fastestAccentColor = fastestAccentColor
        self.fastestBackgroundColor = fastestBackgroundColor
    }
}

public protocol FlagView: View {
    func appearance(_ appearance: FlagAppearance) -> Self
}

public struct SimpleFlagView: FlagView {
    public let regionCode: String

    public var body: some View {
        ImageAsset(name: "Flags/\(regionCode)")
            .swiftUIImage
            .frame(.flagIconSize)
            .cornerRadius(.themeRadius4)
    }

    public func appearance(_ appearance: FlagAppearance) -> Self { self }

    public init(regionCode: String) {
        self.regionCode = regionCode
    }
}

private struct FlagShadowView: View {
    let shadowColor: Color

    var body: some View {
        Path { path in
            path.move(to: .init(x: 0, y: 0))
            path.addLine(to: .init(x: 0, y: 2))
            path.addArc(
                center: .init(x: 4, y: 2),
                radius: 4,
                startAngle: .degrees(180),
                endAngle: .degrees(90),
                clockwise: true
            )
            path.addLine(to: .init(x: 12.5, y: 6))
        }
        .stroke(shadowColor, lineWidth: 3)
        .frame(.flagIconSize)
    }
}

private struct SecureCoreFlagCurveView: View {
    let curveColor: Color

    var body: some View {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: .init(x: 0, y: 8))
            path.addArc(
                center: .init(x: 8, y: 8),
                radius: 8,
                startAngle: .degrees(180),
                endAngle: .degrees(90),
                clockwise: true
            )
            path.addLine(to: .init(x: 24, y: 16))
        }
        .stroke(style: .init(lineWidth: 2, lineCap: .round))
        .foregroundColor(curveColor)
        .frame(width: 26, height: 16)
    }
}

public struct SecureCoreFlagView: FlagView {
    public let regionCode: String
    public let viaRegionCode: String?
    public let flagCurveColor: Color
    public let flagShadowColor: Color

    public var body: some View {
        ZStack {
            if let viaRegionCode {
                ImageAsset(name: "Flags/\(viaRegionCode)")
                    .swiftUIImage
                    .resizable()
                    .frame(.square(AppTheme.IconSize.secureCoreFlagIconSize.width!))
                    .frame(.secureCoreFlagIconSize)
                    .cornerRadius(.themeRadius2½)
                    .offset(.init(width: -14, height: 12))
                FlagShadowView(shadowColor: flagShadowColor)
                    .offset(x: -1.5, y: 16.5)
            } else {
                SecureCoreFlagCurveView(curveColor: flagShadowColor)
                    .offset(x: -6, y: 6)
            }
            SimpleFlagView(regionCode: regionCode)
        }
    }

    public func appearance(_ appearance: FlagAppearance) -> Self {
        Self(
            regionCode: regionCode,
            viaRegionCode: viaRegionCode,
            flagShadowColor: appearance.secureCoreFlagShadowColor
        )
    }

    public init(
        regionCode: String,
        viaRegionCode: String?,
        flagCurveColor: Color? = nil,
        flagShadowColor: Color? = nil
    ) {
        self.regionCode = regionCode
        self.viaRegionCode = viaRegionCode
        self.flagCurveColor = flagCurveColor ?? Color(.gray)
        self.flagShadowColor = flagShadowColor ?? Color(.black).opacity(0.4)
    }
}

public struct FastestFlagView: FlagView {
    let secureCore: Bool
    let boltColor: Color
    let backgroundColor: Color

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)
                .frame(.flagIconSize)
                .cornerRadius(.themeRadius4)
            Image(systemName: "bolt.fill")
                .renderingMode(.template)
                .resizable()
                .frame(.rect(width: 10, height: 14))
                .foregroundColor(boltColor)
            if secureCore {
                SecureCoreFlagCurveView(curveColor: backgroundColor)
                    .offset(.init(width: -6, height: 6))
            }
        }
    }

    public func appearance(_ appearance: FlagAppearance) -> Self {
        Self(
            secureCore: secureCore,
            boltColor: appearance.fastestAccentColor,
            backgroundColor: appearance.fastestBackgroundColor
        )
    }

    public init(secureCore: Bool, boltColor: Color? = nil, backgroundColor: Color? = nil) {
        self.secureCore = secureCore
        self.boltColor = boltColor ?? .yellow
        self.backgroundColor = backgroundColor ?? .green
    }

    public static let boltColor: Color = .init(cgColor: .init(
        red: 0.09375,
        green: 0.7617,
        blue: 0.5938,
        alpha: 1
    ))
}

#if DEBUG
extension FlagAppearance {
    static let previews: Self = .init(
        secureCoreFlagShadowColor: .black.opacity(0.4),
        secureCoreFlagCurveColor: .init(.separator),
        fastestAccentColor: FastestFlagView.boltColor,
        fastestBackgroundColor: .init(cgColor: .init(
            red: 0.1094,
            green: 0.6094,
            blue: 0.4844,
            alpha: 0.3
        ))
    )
}

struct Flags_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SimpleFlagView(regionCode: "CH")
                .appearance(.previews)
                .border(.black.opacity(0.5))
                .padding([.bottom])
            SecureCoreFlagView(regionCode: "US", viaRegionCode: "SE")
                .appearance(.previews)
                .border(.black.opacity(0.5))
                .padding([.bottom])
            SecureCoreFlagView(regionCode: "JP", viaRegionCode: nil)
                .appearance(.previews)
                .border(.black.opacity(0.5))
                .padding([.bottom])
            FastestFlagView(secureCore: false)
                .appearance(.previews)
                .border(.black.opacity(0.5))
                .padding([.bottom])
            FastestFlagView(secureCore: true)
                .appearance(.previews)
                .border(.black.opacity(0.5))
        }
    }
}
#endif
