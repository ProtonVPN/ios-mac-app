//
//  ServerFeature.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Theme
import VPNAppCore

extension ServerFeature {
    private var featureName: String {
        switch self {
        case .secureCore:
            return "secureCore"
        case .tor:
            return "tor"
        case .p2p:
            return "p2p"
        case .streaming:
            return "streaming"
        case .ipv6:
            return "ipv6"
        case .partner:
            return "partnership"
        default:
            return ""
        }
    }

    func commaSeparatedList(isFree: Bool) -> String {
        let featureNames = (isFree ? ["free"] : [])
        return featureNames
            .appending(elements().map(\.featureName))
            .joined(separator: ",")
    }
}
