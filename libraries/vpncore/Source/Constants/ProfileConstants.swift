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
import ProtonCore_UIFoundations
#elseif canImport(Cocoa)
import Cocoa
#endif

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
    public static let profileColors = [
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
    #elseif canImport(Cocoa)
    public static let profileColors = [
        NSColor(red: 224 / 255, green: 32 / 255, blue: 39 / 255, alpha: 1.0),
        NSColor(red: 190 / 255, green: 102 / 255, blue: 103 / 255, alpha: 1.0),
        NSColor(red: 210 / 255, green: 41 / 255, blue: 182 / 255, alpha: 1.0),
        NSColor(red: 177 / 255, green: 82 / 255, blue: 163 / 255, alpha: 1.0),
        NSColor(red: 158 / 255, green: 78 / 255, blue: 216 / 255, alpha: 1.0),
        NSColor(red: 147 / 255, green: 106 / 255, blue: 176 / 255, alpha: 1.0),
        NSColor(red: 95 / 255, green: 115 / 255, blue: 216 / 255, alpha: 1.0),
        NSColor(red: 104 / 255, green: 113 / 255, blue: 165 / 255, alpha: 1.0),
        NSColor(red: 59 / 255, green: 197 / 255, blue: 201 / 255, alpha: 1.0),
        NSColor(red: 87 / 255, green: 145 / 255, blue: 146 / 255, alpha: 1.0),
        NSColor(red: 62 / 255, green: 185 / 255, blue: 102 / 255, alpha: 1.0),
        NSColor(red: 91 / 255, green: 147 / 255, blue: 110 / 255, alpha: 1.0),
        NSColor(red: 152 / 255, green: 184 / 255, blue: 59 / 255, alpha: 1.0),
        NSColor(red: 144 / 255, green: 158 / 255, blue: 102 / 255, alpha: 1.0),
        NSColor(red: 223 / 255, green: 189 / 255, blue: 82 / 255, alpha: 1.0),
        NSColor(red: 163 / 255, green: 147 / 255, blue: 98 / 255, alpha: 1.0),
        NSColor(red: 215 / 255, green: 114 / 255, blue: 39 / 255, alpha: 1.0),
        NSColor(red: 169 / 255, green: 125 / 255, blue: 88 / 255, alpha: 1.0)   ]
    #endif
}
