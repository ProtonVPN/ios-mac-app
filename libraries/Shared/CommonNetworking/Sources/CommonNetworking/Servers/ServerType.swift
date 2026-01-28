//
//  ServerType.swift
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

import Domain
import Persistence
import Strings

public extension ServerType {
    static let humanReadableCases: [Self] = [.standard, .secureCore, .p2p, .tor]

    var localizedString: String {
        switch self {
        case .standard:
            Localizable.standard
        case .secureCore:
            Localizable.secureCore
        case .p2p:
            Localizable.p2p
        case .tor:
            Localizable.tor
        case .unspecified:
            "Unspecified"
        }
    }
}

public extension ServerType {
    /// Feature filter for searching the repository
    var serverTypeFilter: VPNServerFilter.ServerFeatureFilter {
        switch self {
        case .standard:
            .standard
        case .secureCore:
            .secureCore
        case .p2p:
            .standard(with: .p2p)
        case .tor:
            .standard(with: .tor)
        case .unspecified:
            .standard
        }
    }

    var serverFilter: VPNServerFilter {
        switch self {
        case .secureCore:
            .features(.secureCore)
        case .tor:
            .features(.standard(with: .tor))
        case .standard:
            .features(.standard)
        case .p2p:
            .features(.standard(with: .p2p))
        case .unspecified:
            .features(.init(required: .zero, excluded: .zero))
        }
    }
}
