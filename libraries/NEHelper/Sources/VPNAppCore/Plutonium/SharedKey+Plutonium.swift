//
//  Created on 2025-05-12 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
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

#if canImport(AppKit)

import Foundation

import ComposableArchitecture

private enum PlutoniumFile: String {
    case excludeList = "plutoniumExcludeMode.json"
    case includeList = "plutoniumIncludeMode.json"
    case plutoniumFeature = "plutoniumFeature.json"
}

public enum PlutoniumFeatureToggle: Codable {
    public enum Mode: CaseIterable, Codable {
        case exclusion
        case inclusion
    }

    case disabled(Mode)
    case enabled(Mode)

    public var mode: Mode {
        switch self {
        case .disabled(let mode), .enabled(let mode):
            return mode
        }
    }
}

public struct PlutoniumActivated: Codable {
    public var apps: [PlutoniumApp]
    public var ips: [String]
    public init(apps: [PlutoniumApp] = [], ips: [String] = []) {
        self.apps = apps
        self.ips = ips
    }
}

private extension URL {
    static func plutoniumDirectory(for file: PlutoniumFile) -> URL {
        .applicationSupportDirectory.appending(component: file.rawValue)
    }
    static var excludeListURL: URL {
        .plutoniumDirectory(for: .excludeList)
    }
    static var includeListURL: URL {
        .plutoniumDirectory(for: .includeList)
    }
    static var plutoniumFeatureURL: URL {
        .plutoniumDirectory(for: .plutoniumFeature)
    }
}

public extension SharedKey where Self == FileStorageKey<PlutoniumActivated>.Default {
    static var inclusionActivated: Self {
        self[.fileStorage(.includeListURL), default: .init()]
    }
}

public extension SharedKey where Self == FileStorageKey<PlutoniumActivated>.Default {
    static var exclusionActivated: Self {
        self[.fileStorage(.excludeListURL), default: .init()]
    }
}

public extension SharedKey where Self == FileStorageKey<PlutoniumFeatureToggle>.Default {
    static var plutoniumFeature: Self {
        self[.fileStorage(.plutoniumFeatureURL), default: .disabled(.exclusion)]
    }
}

#endif
