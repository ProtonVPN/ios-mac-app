//
//  Created on 2026-02-02 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Domain
import ProtonCoreUIFoundations
import SwiftUI
import Theme

public struct CityStateServerFeaturesView: View {
    #if os(macOS)
        let edgeLength = CGFloat.themeSpacing20
    #elseif os(iOS)
        let edgeLength = CGFloat.themeSpacing16
    #endif

    let hasP2P: Bool
    let hasTor: Bool
    let hasSmartRouting: Bool
    let load: Int?

    public init(hasP2P: Bool, hasTor: Bool, hasSmartRouting: Bool, load: Int?) {
        self.hasP2P = hasP2P
        self.hasTor = hasTor
        self.hasSmartRouting = hasSmartRouting
        self.load = load
    }

    public init(server: ServerInfo) {
        self.init(
            hasP2P: server.logical.feature.contains(.p2p),
            hasTor: server.logical.feature.contains(.tor),
            hasSmartRouting: server.logical.isVirtual,
            load: server.logical.isUnderMaintenance ? nil : server.logical.load
        )
    }

    public init(groupInfo: ServerGroupInfo) {
        self.init(
            hasP2P: groupInfo.featureUnion.contains(.p2p),
            hasTor: groupInfo.featureUnion.contains(.tor),
            hasSmartRouting: groupInfo.supportsSmartRouting,
            load: nil
        )
    }

    public var body: some View {
        HStack(spacing: .themeSpacing8) {
            if hasP2P {
                IconProvider.arrowRightArrowLeft
                    .resizable()
                    .frame(.square(edgeLength))
            }
            if hasTor {
                IconProvider.brandTor
                    .resizable()
                    .frame(.square(edgeLength))
            }
            if hasSmartRouting {
                IconProvider.globe
                    .resizable()
                    .frame(.square(edgeLength))
            }
            #if os(iOS)
                if let load {
                    Spacer()
                        .frame(width: .themeSpacing8)
                    LoadView(load: load)
                }
            #endif
        }
    }
}
