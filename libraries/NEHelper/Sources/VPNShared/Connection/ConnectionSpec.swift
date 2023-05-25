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

import Theme

public struct ConnectionSpec: Equatable, Hashable {
    public enum Server: Equatable, Hashable {
        case free
        case paid
    }

    public enum SecureCoreSpec: Equatable, Hashable {
        case fastest
        case fastestHop(to: String)
        case hop(to: String, via: String)
    }

    public enum Location: Equatable, Hashable {
        case fastest
        case region(code: String)
        case exact(Server, number: Int, subregion: String?, regionCode: String)
        case secureCore(SecureCoreSpec)
    }

    public enum Feature: Equatable, Hashable, CustomStringConvertible {
        case smart
        case streaming
        case p2p
        case tor
        case partner(name: String)

        // TODO: Localized strings
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

    public let location: Location
    public let features: Set<Feature>

    public init(location: Location, features: Set<Feature>) {
        self.location = location
        self.features = features
    }
}
