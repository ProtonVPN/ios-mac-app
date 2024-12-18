//
//  Created on 28/11/2024.
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

import Domain
import Ergonomics
import Dependencies

public struct ServerSelector: Sendable {
    public var select: @Sendable (_ spec: ConnectionSpec) throws -> Server

    public enum SelectionError: Error {
        case noLogical
        case noEndpoints
    }
}

extension ServerSelector: DependencyKey {
    public static let liveValue = ServerSelector(select: { spec in
        @Dependency(\.serverRepository) var repository

        let server = repository.getFirstServer(filteredBy: spec.serverFilters, orderedBy: spec.order)

        guard let server else {
            throw SelectionError.noLogical
        }

        // VPNAPPL-2506: choose endpoint according to protocol we are connecting with
        guard let endpoint = server.endpoints.randomElement() else {
            throw SelectionError.noEndpoints
        }

        return Server(logical: server.logical, endpoint: endpoint)
    })
}

extension DependencyValues {
    public var serverSelector: ServerSelector {
        get { self[ServerSelector.self] }
        set { self[ServerSelector.self] = newValue }
    }
}

extension ConnectionSpec.Location {
    var isSecureCore: Bool {
        if case .secureCore = self {
            return true
        }
        return false
    }
}

extension ConnectionSpec {
    var order: VPNServerOrder {
        switch location {
        case .random:
            return .random
        case .secureCore(.random):
            return .random
        default:
            return .fastest
        }
    }

    var serverFilters: [VPNServerFilter] {
        let allFilters: [[VPNServerFilter?]] = [[featureFilter], [serverTierFilter], locationFilters]

        return allFilters
            .flatMap(\.self)
            .compactMap(\.self)
    }

    private var featureFilter: VPNServerFilter {
        let additionalFeatures: [ServerFeature] = features
            .compactMap { ServerFeature.init(connectionSpecFeature: $0) }

        if location.isSecureCore {
            assert(additionalFeatures.isEmpty, "Secure Core should be disjoint with other features")
            return .features(.secureCore)
        } else {
            return .features(.standard(with: ServerFeature(additionalFeatures)))
        }
    }

    private var serverTierFilter: VPNServerFilter? {
        switch location {
        case .exact(.free, _, _, _):
            return .tier(.max(tier: 0))

        default:
            return nil
        }
    }

    private var locationFilters: [VPNServerFilter] {
        switch location {
        case .fastest, .random, .secureCore(.random), .secureCore(.fastest):
            return []

        case .region(let code):
            return [.exitCountryCode(code)]

        case .exact(_, let number, let subRegion, let region):
            return [
                Self.regionFilter(region: region, number: number),
                subRegion.map(VPNServerFilter.city)
            ].compactMap(\.self)

        case .secureCore(.fastestHop(let to)):
            return [.exitCountryCode(to)]

        case .secureCore(.hop(let to, let via)):
            return [.exitCountryCode(to), .entryCountryCode(via)]
        }
    }

    private static func regionFilter(region: String, number: Int?) -> VPNServerFilter {
        guard let number else {
            return .exitCountryCode(region)
        }
        return .matches("\(region)#\(number)")
    }
}
