//
//  Created on 13/07/2023.
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

import Domain
import Theme
import VPNAppCore

public struct FlagView: View {
    let flagComposition: FlagComposition
    let flagSize: FlagSizes

    public init(flag: Flag, flagSize: FlagSizes) {
        self.flagComposition = .standard(flag)
        self.flagSize = flagSize
    }

    public init(flag: FlagComposition, flagSize: FlagSizes) {
        self.flagComposition = flag
        self.flagSize = flagSize
    }

    public init(location: ConnectionSpec.Location, flagSize: FlagSizes) {
        self.flagComposition = location.flagComposition
        self.flagSize = flagSize
    }

    public var body: some View {
        switch flagComposition {
        case let .standard(flag):
            SimpleFlagView(regionCode: flag.imageName, flagSize: flagSize)

        case let .withCurve(flag):
            SecureCoreFlagView(
                regionCode: flag.imageName,
                viaRegionCode: nil,
                flagSize: flagSize
            )

        case let .stacked(bottom, top):
            SecureCoreFlagView(
                regionCode: top.imageName,
                viaRegionCode: bottom.imageName,
                flagSize: flagSize
            )
        }
    }
}

struct SecureCoreFlagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            standardFlags
            secureCoreFlags
        }
        .previewLayout(.sizeThatFits)
    }

    static var standardFlags: some View {
        HStack(spacing: 8) {
            FlagView(location: .fastest, flagSize: .defaultSize)
            FlagView(location: .random, flagSize: .defaultSize)
            FlagView(location: .region(code: "PL"), flagSize: .defaultSize)
        }
        .padding(8)
    }

    static var secureCoreFlags: some View {
        HStack(spacing: 8) {
            FlagView(location: .secureCore(.fastest), flagSize: .defaultSize)
            FlagView(location: .secureCore(.fastestHop(to: "CZ")), flagSize: .defaultSize)
            FlagView(location: .secureCore(.hop(to: "GB", via: "LT")), flagSize: .defaultSize)
        }
        .padding(8)
    }
}

public extension ConnectionSpec.Location {
    var flagComposition: FlagComposition {
        switch self {
        case .random:
            .standard(.random)

        case .fastest:
            .standard(.fastest)

        case .gateway:
            .standard(.gateway)

        case let .region(regionCode), let .exact(_, _, _, _, regionCode):
            .standard(.country(code: regionCode))

        case .secureCore(.fastest):
            .withCurve(.fastest)

        case .secureCore(.random):
            .withCurve(.random)

        case let .secureCore(.fastestHop(regionCode)):
            .withCurve(.country(code: regionCode))

        case let .secureCore(.hop(toRegionCode, viaRegionCode)):
            .stacked(bottom: .country(code: viaRegionCode), top: .country(code: toRegionCode))
        }
    }
}
