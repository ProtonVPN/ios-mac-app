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

public struct FlagSizes {

    let frame: CGSize

    // Simple flag
    let simpleFlag: CGSize

    // Secure Core with via
    let scTopFlag: CGSize
    let scBottomFlag: CGSize

    // Main view corner radius
    let cornerRadius: CGFloat

    let folder: String

    public static var defaultSize: Self {
        Self(
            frame: CGSize(width: 30, height: 24),
            simpleFlag: CGSize(width: 30, height: 20),
            scTopFlag: CGSize(width: 24, height: 16),
            scBottomFlag: CGSize(width: 18, height: 12), 
            cornerRadius: .themeRadius4,
            folder: "Flags/"
        )
    }

    public static var desktopRecentsSize: Self {
        Self(
            frame: CGSize(width: 24, height: 16),
            simpleFlag: CGSize(width: 24, height: 16),
            scTopFlag: CGSize(width: 18, height: 12),
            scBottomFlag: CGSize(width: 15, height: 10),
            cornerRadius: .themeRadius4,
            folder: "Flags/"
        )
    }

    public static var tvListSize: Self {
        Self(
            frame: CGSize(width: 210, height: 140),
            simpleFlag: CGSize(width: 210, height: 140),
            scTopFlag: CGSize(width: 20, height: 40),
            scBottomFlag: CGSize(width: 20, height: 40),
            cornerRadius: .themeRadius24,
            folder: ""
        )
    }
}

public struct SimpleFlagView: View {
    public let regionCode: String

    public let startSize: CGSize
    public let cornerRadius: CGFloat
    @ScaledMetric var scale: CGFloat = 1

    let folder: String

    public var body: some View {
        ImageAsset(name: "\(folder)\(regionCode)")
            .swiftUIImage
            .resizable()
            .cornerRadius(cornerRadius * scale)
            .frame(width: startSize.width * scale,
                   height: startSize.height * scale)
    }

    fileprivate init(regionCode: String, size: CGSize, cornerRadius: CGFloat = .themeRadius4) {
        self.regionCode = regionCode
        self.startSize = size
        self.cornerRadius = cornerRadius
        self.folder = "Flags/"
    }

    public init(regionCode: String, flagSize: FlagSizes) {
        self.regionCode = regionCode
        self.startSize = flagSize.simpleFlag
        self.cornerRadius = flagSize.cornerRadius
        self.folder = flagSize.folder
    }
}

private struct FlagShadowView: View {
    let shadowColor: Color

    public let flagSize: FlagSizes
    @ScaledMetric var scale: CGFloat = 1

    var body: some View {
        Path { path in
            path.move(to: .init(x: 0 * scale, y: 0 * scale))
            path.addLine(to: .init(x: 0 * scale, y: 2 * scale))
            path.addArc(
                center: .init(x: 4 * scale, y: 2 * scale),
                radius: 4 * scale,
                startAngle: .degrees(180),
                endAngle: .degrees(90),
                clockwise: true
            )
            path.addLine(to: .init(x: (flagSize.scBottomFlag.width - (flagSize.frame.width - flagSize.scTopFlag.width - 1)) * scale, y: 6 * scale))
        }
        .stroke(shadowColor, lineWidth: 2 * scale)
        .frame(width: flagSize.scBottomFlag.width * scale,
               height: flagSize.scBottomFlag.height * scale)
    }
}

fileprivate struct SecureCoreFlagCurveView: View {
    let curveColor: Color

    public let startSize: CGSize
    @ScaledMetric var scale: CGFloat = 1
    private let radius: CGFloat = 7.0
    private let width: CGFloat = 2.0

    var body: some View {
        Path { path in
            path.move(to: .init(x: 0, y: radius * scale))
            path.addLine(to: .init(x: 0, y: (startSize.height - radius) * scale))
            path.addArc(
                center: .init(x: radius * scale, y: (startSize.height - radius) * scale),
                radius: radius * scale,
                startAngle: .degrees(180),
                endAngle: .degrees(90),
                clockwise: true
            )
            path.addLine(to: .init(x: (startSize.width - radius) * scale, y: startSize.height * scale))
        }
        .stroke(style: .init(lineWidth: width * scale, lineCap: .round))
        .foregroundColor(curveColor)
    }
}

public struct SecureCoreFlagView: View {
    public let regionCode: String
    public let viaRegionCode: String?
    public let flagShadowColor: Color = .black.opacity(0.4)
    public let flagCurveColor: Color = Color(.text, .hint)

    let flagSize: FlagSizes
    @ScaledMetric var scale: CGFloat = 1

    public var body: some View {
        ZStack(alignment: .init(horizontal: .leading, vertical: .top)) {
            if let viaRegionCode {
                ImageAsset(name: "Flags/\(viaRegionCode)")
                    .swiftUIImage
                    .resizable()
                    .frame(width: flagSize.scBottomFlag.width * scale,
                           height: flagSize.scBottomFlag.height * scale)
                    .cornerRadius(.themeRadius2½ * scale)
                    .padding([.top], (flagSize.frame.height - flagSize.scBottomFlag.height) * scale)

                FlagShadowView(shadowColor: flagShadowColor, flagSize: flagSize)
                    .padding([.leading], (flagSize.frame.width - flagSize.scTopFlag.width - 1) * scale)
                    .padding([.top], (flagSize.frame.height - flagSize.scBottomFlag.height) * scale)

                SimpleFlagView(regionCode: regionCode, size: flagSize.scTopFlag)
                    .padding([.leading], (flagSize.frame.width - flagSize.scTopFlag.width) * scale)

            } else {

                SecureCoreFlagCurveView(curveColor: flagCurveColor, startSize: flagSize.simpleFlag)
                    .frame(width: flagSize.simpleFlag.width * scale,
                           height: flagSize.simpleFlag.height * scale)
                    .offset(x: -3 * scale, y: 3 * scale)

                SimpleFlagView(regionCode: regionCode, size: flagSize.simpleFlag)
            }
        }
    }

    public init(
        regionCode: String,
        viaRegionCode: String?,
        flagSize: FlagSizes
    ) {
        self.regionCode = regionCode
        self.viaRegionCode = viaRegionCode
        self.flagSize = flagSize
    }
}

struct Flags_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            VStack {
                SimpleFlagView(regionCode: "CH", flagSize: .defaultSize)

                SecureCoreFlagView(regionCode: "US", viaRegionCode: "SE", flagSize: .defaultSize)

                SecureCoreFlagView(regionCode: "AU", viaRegionCode: nil, flagSize: .defaultSize)

                SimpleFlagView(regionCode: "Fastest", flagSize: .defaultSize)

                SecureCoreFlagView(regionCode: "Fastest", viaRegionCode: nil, flagSize: .defaultSize)
            }
            VStack {
                SimpleFlagView(regionCode: "CH", flagSize: .desktopRecentsSize)

                SecureCoreFlagView(regionCode: "US", viaRegionCode: "CH", flagSize: .desktopRecentsSize)

                SecureCoreFlagView(regionCode: "AU", viaRegionCode: nil, flagSize: .desktopRecentsSize)

                SimpleFlagView(regionCode: "Fastest", flagSize: .desktopRecentsSize)

                SecureCoreFlagView(regionCode: "Fastest", viaRegionCode: nil, flagSize: .desktopRecentsSize)
            }
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
