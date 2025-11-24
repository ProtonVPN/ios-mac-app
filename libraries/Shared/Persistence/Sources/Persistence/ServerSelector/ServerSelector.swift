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

import Foundation

import Dependencies
import IssueReporting

import Domain
import Ergonomics

extension ServerSelector: DependencyKey {
    public static let liveValue = ServerSelector(select: { spec, userTier, acceptableProtocols throws(SelectionError) -> Server in
        @Dependency(\.serverRepository) var repository

        let tierFilter: VPNServerFilter? = userTier == .freeTier ? .tier(.max(tier: .freeTier)) : nil
        let baseFilters = spec.locationFilters + [tierFilter, spec.serverTierFilter].compactMap { $0 }

        var servers = repository.getServers(filteredBy: baseFilters, orderedBy: spec.order)
        log.debug("Got \(servers.count) servers with \(baseFilters.map(\.description).joined())...")

        guard !servers.isEmpty else {
            throw .noLogical(.locationNotFound(spec.location))
        }

        let steps: [(VPNServerFilter, SelectionError.LogicalResolutionFailureReason)] = [
            (.features(spec.serverFeatureFilter), .featuresNotSupported(spec.features)),
            (.supports(protocol: acceptableProtocols), .protocolNotSupported(acceptableProtocols)),
            (.isNotUnderMaintenance, .maintenance),
        ]

        for (filter, reason) in steps {
            let oldServers = servers
            log.debug("Applying filter \(filter) to \(servers.count) servers...")

            servers = servers.filter(filter)
            guard !servers.isEmpty else {
                log.debug("No logicals remaining - servers were \(oldServers)")
                throw .noLogical(reason)
            }
        }

        let logical = servers.first!.logical
        guard let server = repository.getFirstServer(filteredBy: [.logicalID(logical.id)], orderedBy: spec.order) else {
            reportIssue("Inconsistent DB: the logical with id \(logical.id) should exist. (Filter: \(spec))")
            log.assertionFailure("No logical exists with id \(logical.id), spec: \(spec)")
            throw .noLogical(.maintenance)
        }

        let endpointsSupportingProtocol = server.endpoints.filter { $0.supports(protocolSet: acceptableProtocols) }
        if endpointsSupportingProtocol.isEmpty {
            log.debug("No endpoint supported protocol set. Logical: \(logical)")
            throw .noEndpoints(.protocolNotSupported(acceptableProtocols))
        }

        let availableEndpoints = endpointsSupportingProtocol.filter { !$0.isUnderMaintenance }
        guard let endpoint = availableEndpoints.randomElement() else {
            log.debug("No endpoint not under maintenance. Logical: \(logical)")
            throw .noEndpoints(.maintenance)
        }

        return Server(logical: server.logical, endpoint: endpoint)
    })
}

extension [ServerInfo] {
    func filter(_ filter: VPNServerFilter) -> Self {
        self.filter(filter.allows(_:))
    }
}

extension VPNServerFilter {
    func allows(_ info: ServerInfo) -> Bool {
        switch self {
        case let .features(filter):
            let hasAllRequiredFeatures = info.logical.feature.intersection(filter.required) == filter.required
            let hasNoExcludedFeatures = info.logical.feature.intersection(filter.excluded).isEmpty
            return hasAllRequiredFeatures && hasNoExcludedFeatures
        case let .supports(vpnProtocol):
            return info.protocolSupport.contains(vpnProtocol)
        case .isNotUnderMaintenance:
            return !info.logical.isUnderMaintenance
        default:
            reportIssue("The filter \(self) should either be used through GRDB or have an explicit case defined.")
            log.assertionFailure("Unexpected filter \(self)")
            return false
        }
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
            .random
        case .secureCore(.random):
            .random
        default:
            .fastest
        }
    }

    var serverFeatureFilter: VPNServerFilter.ServerFeatureFilter {
        .init(required: requiredFeatureSet, excluded: excludedFeatureSet)
    }

    private var excludedFeatureSet: ServerFeature {
        location.isSecureCore ? .zero : .secureCore
    }

    private var requiredFeatureSet: ServerFeature {
        var requiredFeatures: [ServerFeature] = features
            .compactMap { ServerFeature(connectionSpecFeature: $0) }
        if location.isSecureCore {
            requiredFeatures.append(.secureCore)
        }
        return ServerFeature(requiredFeatures)
    }

    var serverTierFilter: VPNServerFilter? {
        switch location {
        case .exact(.free, _, _, _, _):
            .tier(.max(tier: 0))

        default:
            nil
        }
    }

    var locationFilters: [VPNServerFilter] {
        switch location {
        case .fastest, .random, .secureCore(.random), .secureCore(.fastest):
            []

        case let .region(code):
            [.exitCountryCode(code)]

        case let .gateway(name):
            [.kind(.gateway(name: name))]

        case let .exact(_, logicalID, number, subRegion, region):
            logicalID.map { [.logicalID($0)] } ?? [
                Self.regionFilter(region: region, number: number),
                subRegion.map(VPNServerFilter.city),
            ].compactMap { $0 }

        case let .secureCore(.fastestHop(to)):
            [.exitCountryCode(to)]

        case let .secureCore(.hop(to, via)):
            [.exitCountryCode(to), .entryCountryCode(via)]
        }
    }

    private static func regionFilter(region: String, number: Int?) -> VPNServerFilter {
        guard let number else {
            return .exitCountryCode(region)
        }
        return .matches("\(region)#\(number)")
    }
}

extension Domain.Logical {
    func satisfies(_ filter: VPNServerFilter.ServerFeatureFilter) -> Bool {
        feature.isDisjoint(with: filter.excluded) && feature.isSuperset(of: filter.required)
    }
}
