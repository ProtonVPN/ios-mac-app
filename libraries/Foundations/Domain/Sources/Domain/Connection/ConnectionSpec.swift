//
//  Created on 17.05.23.
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
import Strings

/// Defines users intent as to where (s)he wanted to connect
public struct ConnectionSpec: Equatable, Hashable, Codable {

    public let location: Location
    public let features: Set<Feature>

    // MARK: -

    public enum Server: Equatable, Hashable, Codable {
        case free
        case paid
    }

    public enum SecureCoreSpec: Equatable, Hashable, Codable {
        case fastest
        case fastestHop(to: String)
        case hop(to: String, via: String)
    }

    public enum Location: Equatable, Hashable, Codable {
        case fastest
        case region(code: String)
        case exact(Server, number: Int?, subregion: String?, regionCode: String)
        case secureCore(SecureCoreSpec)
    }

    public enum Feature: Equatable, Hashable, CustomStringConvertible, Identifiable, Codable {
        public var id: Self { self } // Identifiable

        case smart
        case streaming
        case p2p
        case tor
        case partner(name: String)

        // todo: Localized strings
        public var description: String {
            switch self {
            case .smart:
                return "Smart"
            case .streaming:
                return "Streaming"
            case .p2p:
                return "P2P"
            case .tor:
                return "TOR"
            case .partner(let name):
                return name
            }
        }
    }

    // MARK: - Initialisers

    public init(location: Location, features: Set<Feature>) {
        self.location = location
        self.features = features
    }

    /// Default intent that is set before user asks for any
    public init() {
        self.init(location: .fastest, features: [])
    }
}

public extension ConnectionSpec.Location {
    func withServer(number: Int) -> Self {
        switch self {
        case let .exact(server, _, subregion, regionCode):
            return .exact(server, number: number, subregion: subregion, regionCode: regionCode)
        default:
            return self
        }
    }
}

public extension ConnectionSpec.Location {
    static let specificCity = Self.exact(.paid,
                                         number: nil,
                                         subregion: "Szczebrzeszyn",
                                         regionCode: "PL")

    static let specificCityServer = Self.exact(.paid,
                                               number: 456,
                                               subregion: "Szczebrzeszyn",
                                               regionCode: "PL")

    static let specificCountryServer = Self.exact(.free,
                                                  number: 123,
                                                  subregion: nil,
                                                  regionCode: "PL")
}

public extension ConnectionSpec {
    static let defaultFastest = ConnectionSpec(location: .fastest, features: [])
    static let secureCoreFastest = ConnectionSpec(location: .secureCore(.fastest), features: [])
    static let secureCoreCountry = ConnectionSpec(location: .secureCore(.fastestHop(to: "US")), features: [])
    static let secureCoreCountryHop = ConnectionSpec(location: .secureCore(.hop(to: "US", via: "CA")), features: [])
    static let specificCountry = ConnectionSpec(location: .region(code: "CH"), features: [])
    static let specificCity = ConnectionSpec(location: .specificCity, features: [])
    static let specificCityServer = ConnectionSpec(location: .specificCityServer, features: [])
    static let specificCountryServer = ConnectionSpec(location: .specificCountryServer, features: [])

    func withAllFeatures() -> Self {
        .init(location: location, features: [.p2p, .tor])
    }
}
