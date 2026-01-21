//
//  Created on 16/10/2024.
//
//  Copyright (c) 2024 Proton AG
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

import CommonNetworking
import Domain
import ProtonCoreFeatureFlags

public extension ConnectionSpec {
    init(connectionRequest: ConnectionRequest) {
        let location: ConnectionSpec.Location
        var features: Set<ConnectionSpec.Feature> = []
        switch connectionRequest.connectionType {
        case .fastest:
            location = connectionRequest.serverType == .secureCore ? .secureCore(.any(.fastest)) : .any(.fastest)
        case .random:
            location = connectionRequest.serverType == .secureCore ? .secureCore(.any(.random)) : .any(.random)
        case let .gateway(name):
            location = .gateway(name: name)
        case let .country(country, type):
            switch type {
            case .fastest:
                if connectionRequest.serverType == .secureCore {
                    location = .secureCore(.anyHop(to: country, .fastest))
                } else {
                    location = .country(code: country, order: .fastest)
                }
            case .random:
                if connectionRequest.serverType == .secureCore {
                    location = .secureCore(.anyHop(to: country, .random))
                } else {
                    location = .country(code: country, order: .random)
                }
            case let .server(serverModel):
                if serverModel.feature.contains(.streaming) {
                    features.insert(.streaming)
                }
                if serverModel.feature.contains(.p2p) {
                    features.insert(.p2p)
                }
                if serverModel.feature.contains(.tor) {
                    features.insert(.tor)
                }
                if serverModel.feature.contains(.secureCore) {
                    location = .secureCore(.hop(to: serverModel.exitCountryCode, via: serverModel.entryCountryCode))
                } else {
                    location = .exact(
                        .paid,
                        logicalID: serverModel.id,
                        number: serverModel.serverNameComponents.sequence,
                        subregion: serverModel.city,
                        regionCode: country
                    )
                }
            }
        case let .city(name, code):
            location = .city(name: name, code: code)
        case let .state(name, code):
            location = .state(name: name, code: code)
        }
        self = .init(location: location, features: features, profileId: connectionRequest.profileId)
    }
}
