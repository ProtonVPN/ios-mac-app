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
import Theme
import SwiftUI
import VPNAppCore

public struct FlagView: View {
    let location: ConnectionSpec.Location
    let flagSize: FlagSizes

    public init(location: ConnectionSpec.Location, flagSize: FlagSizes) {
        self.location = location
        self.flagSize = flagSize
    }

    public var body: some View {
        switch location {
        case .fastest:
            SimpleFlagView(regionCode: "Fastest", flagSize: flagSize)
        case .region(let regionCode), .exact(_, _, _, let regionCode):
            SimpleFlagView(regionCode: regionCode, flagSize: flagSize)
        case .secureCore(let secureCoreSpec):
            SecureCoreFlagView(secureCoreSpec: secureCoreSpec, flagSize: flagSize)
        }
    }
}

extension SecureCoreFlagView {
    init(secureCoreSpec: ConnectionSpec.SecureCoreSpec, flagSize: FlagSizes) {
        switch secureCoreSpec {
        case .fastest:
            self = SecureCoreFlagView(regionCode: "Fastest",
                                      viaRegionCode: nil,
                                      flagSize: flagSize)
        case .fastestHop(to: let regionCode):
            self = SecureCoreFlagView(regionCode: regionCode,
                                      viaRegionCode: nil,
                                      flagSize: flagSize)
        case .hop(to: let toRegion, via: let viaRegion):
            self = SecureCoreFlagView(regionCode: toRegion,
                                      viaRegionCode: viaRegion,
                                      flagSize: flagSize)
        }
    }
}

struct SecureCoreFlagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            FlagView(location: .fastest, flagSize: .defaultSize)
            FlagView(location: .region(code: "PL"), flagSize: .defaultSize)
            FlagView(location: .secureCore(.fastest), flagSize: .defaultSize)
            FlagView(location: .secureCore(.fastestHop(to: "CZ")), flagSize: .defaultSize)
            FlagView(location: .secureCore(.hop(to: "GB", via: "LT")), flagSize: .defaultSize)
        }
        .padding(8)
            .previewLayout(.sizeThatFits)
    }
}
