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
public struct ConnectionSpec: Equatable, Hashable, Codable, Sendable {
    public let location: Location
    public let features: Set<Feature>
    public let profileId: String?

    // MARK: -

    public enum Server: Equatable, Hashable, Codable, Sendable {
        case free
        case paid
    }

    public enum SelectionSpec: Equatable, Hashable, Codable, Sendable {
        case random
        case fastest
    }

    public enum SecureCoreSpec: Equatable, Hashable, Codable, Sendable {
        case any(SelectionSpec)
        case anyHop(to: String, SelectionSpec)
        case hop(to: String, via: String)
    }

    public enum Location: Equatable, Hashable, Codable, Sendable {
        case any(SelectionSpec)
        case country(code: String, order: SelectionSpec)
        case city(name: String, code: String, order: SelectionSpec)
        case state(name: String, code: String, order: SelectionSpec)
        case exact(Server, logicalID: String?, number: Int?, subregion: String?, regionCode: String)
        case secureCore(SecureCoreSpec)
        case gateway(name: String)
    }

    public enum Feature: Equatable, Hashable, CustomStringConvertible, Identifiable, Codable, Sendable {
        public var id: Self { self } // Identifiable

        case smart(hostCountryCode: String, exitCountryCode: String) // smart routing
        case streaming
        case p2p
        case tor

        // TODO: Localized strings
        public var description: String {
            switch self {
            case .smart:
                "Smart"
            case .streaming:
                "Streaming"
            case .p2p:
                "P2P"
            case .tor:
                "TOR"
            }
        }
    }

    // MARK: - Initialisers

    public init(location: Location, features: Set<Feature>, profileId: String? = nil) {
        self.location = location
        self.features = features
        self.profileId = profileId
    }

    /// Default intent that is set before user asks for any
    public init() {
        self.init(location: .any(.fastest), features: [])
    }
}

package extension ConnectionSpec.Feature {
    init?(serverFeature: ServerFeature) {
        switch serverFeature {
        case .streaming:
            self = .streaming
        case .p2p:
            self = .p2p
        case .tor:
            self = .tor
        default:
            return nil
        }
    }
}

public extension ConnectionSpec.Location {
    func withServer(number: Int) -> Self {
        switch self {
        case let .exact(server, logicalID, _, subregion, regionCode):
            .exact(server, logicalID: logicalID, number: number, subregion: subregion, regionCode: regionCode)
        default:
            self
        }
    }

    var selectionSpec: ConnectionSpec.SelectionSpec? {
        switch self {
        case let .any(select),
             let .city(_, _, select),
             let .country(_, select),
             let .secureCore(.any(select)),
             let .secureCore(.anyHop(_, select)):
            select
        default:
            nil
        }
    }
}

#if DEBUG
    public extension ConnectionSpec.Location {
        static let specificCity = Self.exact(
            .paid,
            logicalID: nil,
            number: nil,
            subregion: "Szczebrzeszyn",
            regionCode: "PL"
        )

        static let specificCityServer = Self.exact(
            .paid,
            logicalID: nil,
            number: 456,
            subregion: "Szczebrzeszyn",
            regionCode: "PL"
        )

        static let specificCountryServer = Self.exact(
            .free,
            logicalID: nil,
            number: 123,
            subregion: nil,
            regionCode: "PL"
        )
    }
#endif

public extension ConnectionSpec {
    static let defaultFastest = ConnectionSpec(location: .any(.fastest), features: [])
    static let secureCoreFastest = ConnectionSpec(location: .secureCore(.any(.fastest)), features: [])
    static let secureCoreCountry = ConnectionSpec(location: .secureCore(.anyHop(to: "US", .fastest)), features: [])
    static let secureCoreCountryHop = ConnectionSpec(location: .secureCore(.hop(to: "US", via: "CA")), features: [])
    static let specificCountry = ConnectionSpec(location: .country(code: "CH", order: .fastest), features: [])
    static let specificCity = ConnectionSpec(location: .specificCity, features: [])
    static let specificCityServer = ConnectionSpec(location: .specificCityServer, features: [])
    static let specificCountryServer = ConnectionSpec(location: .specificCountryServer, features: [])

    func with(location: ConnectionSpec.Location) -> Self {
        .init(location: location, features: features)
    }

    func withAllFeatures() -> Self {
        .init(location: location, features: [.p2p, .tor])
    }
}

public extension ConnectionSpec {
    var countryCode: String? {
        switch location {
        case .any:
            break
        case let .city(_, code, _), let .state(_, code, _), let .country(code, _):
            return code
        case .gateway:
            return nil
        case let .exact(_, _, _, _, regionCode):
            return regionCode
        case let .secureCore(spec):
            switch spec {
            case .any:
                break
            case let .anyHop(to, _):
                return to
            case let .hop(to, _):
                return to
            }
        }
        return nil
    }
}
