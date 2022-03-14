//
//  ProfileConstants.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

#if canImport(UIKit)
import UIKit
#elseif canImport(Cocoa)
import Cocoa
#endif
import ProtonCore_UIFoundations

public class ProfileConstants {
    // WARNING: consuming client must contain "fastest" and "random" image assets
    public static func defaultProfiles(connectionProtocol: ConnectionProtocol) -> [Profile] {
        return
            [ Profile(id: "st_f", accessTier: 0, profileIcon: .image(IconProvider.bolt), profileType: .system,
                      serverType: .unspecified, serverOffering: .fastest(nil), name: LocalizedString.fastest, connectionProtocol: connectionProtocol),
              Profile(id: "st_r", accessTier: 0, profileIcon: .image(IconProvider.arrowsSwapRight), profileType: .system,
                      serverType: .unspecified, serverOffering: .random(nil), name: LocalizedString.random, connectionProtocol: connectionProtocol) ]
    }

#if canImport(UIKit)
    public typealias ProfileColors = [UIColor]
#elseif canImport(Cocoa)
    public typealias ProfileColors = [NSColor]
#endif

    public static let profileColors: ProfileColors = [
        ColorProvider.PurpleBase,
        ColorProvider.PinkBase,
        ColorProvider.StrawberryBase,
        ColorProvider.CarrotBase,
        ColorProvider.SaharaBase,
        ColorProvider.SlateblueBase,
        ColorProvider.PacificBase,
        ColorProvider.ReefBase,
        ColorProvider.FernBase,
        ColorProvider.OliveBase
    ]
}
