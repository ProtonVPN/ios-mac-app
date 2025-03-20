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

import Domain
import Ergonomics
import Dependencies

public struct ServerSelector: Sendable {
    public internal(set) var select: @Sendable (
        _ spec: ConnectionSpec,
        _ userTier: Int,
        _ acceptableProtocols: ProtocolSupport
    ) throws(ServerSelectionError) -> Server

    public init(select: @escaping @Sendable (ConnectionSpec, Int, ProtocolSupport) throws(ServerSelectionError) -> Server) {
        self.select = select
    }

    public enum ServerSelectionError: ProtonVPNError, Equatable {
        case noLogical(LogicalResolutionFailureReason)
        case noEndpoints(EndpointResolutionFailureReason)

        public enum LogicalResolutionFailureReason: Equatable {
            case locationNotFound(ConnectionSpec.Location)
            case featuresNotSupported(Set<ConnectionSpec.Feature>)
            case protocolNotSupported(ProtocolSupport)
            case maintenance

            var charCode: FourCharCode {
                switch self {
                case .featuresNotSupported:
                    return "LFNS"
                case .locationNotFound:
                    return "LLNF"
                case .protocolNotSupported:
                    return "LPNS"
                case .maintenance:
                    return "LMNT"
                }
            }

            var userInfo: [String: Any] {
                switch self {
                case let .featuresNotSupported(features):
                    return ["features": features]
                case let .locationNotFound(location):
                    return ["location": location]
                case let .protocolNotSupported(unsupportedProtocol):
                    return ["protocol": unsupportedProtocol]
                case .maintenance:
                    return [:]
                }
            }
        }

        public enum EndpointResolutionFailureReason: Equatable {
            case protocolNotSupported(ProtocolSupport)
            case maintenance

            var charCode: FourCharCode {
                switch self {
                case .protocolNotSupported:
                    return "EPNS"
                case .maintenance:
                    return "EMNT"
                }
            }

            var userInfo: [String: Any] {
                switch self {
                case let .protocolNotSupported(unsupportedProtocol):
                    return ["protocol": unsupportedProtocol]
                case .maintenance:
                    return [:]
                }
            }
        }

        public var charCode: FourCharCode {
            switch self {
            case let .noEndpoints(reason):
                return reason.charCode
            case let .noLogical(reason):
                return reason.charCode
            }
        }

        public var extraUserInfo: [String: Any]? {
            switch self {
            case let .noEndpoints(reason):
                return reason.userInfo
            case let .noLogical(reason):
                return reason.userInfo
            }
        }
    }
}

extension ServerSelector: DependencyKey {
    public static let liveValue = ServerSelector(select: { (spec, userTier, acceptableProtocols) throws(ServerSelectionError) -> Server in
        @Dependency(\.serverRepository) var repository

        let tierFilter: VPNServerFilter? = userTier == .freeTier ? .tier(.max(tier: .freeTier)) : nil
        let baseFilters = spec.locationFilters + [tierFilter, spec.serverTierFilter].compactMap { $0 }

        let additionalFilters: [VPNServerFilter] = [
            .features(spec.serverFeatureFilter),
            .supports(protocol: acceptableProtocols),
            .isNotUnderMaintenance
        ]

        let allFilters = baseFilters + additionalFilters
        let server = repository.getFirstServer(filteredBy: allFilters, orderedBy: spec.order)

        guard let server else {
            let resolutionFailureReason = Self.logicalResolutionFailureReason(
                spec: spec,
                acceptableProtocols: acceptableProtocols,
                baseFilters: baseFilters
            )
            throw ServerSelectionError.noLogical(resolutionFailureReason)
        }

        let endpointsSupportingProtocol = server.endpoints.filter { $0.supports(protocolSet: acceptableProtocols) }
        if endpointsSupportingProtocol.isEmpty {
            throw ServerSelectionError.noEndpoints(.protocolNotSupported(acceptableProtocols))
        }

        let availableEndpoints = endpointsSupportingProtocol.filter { !$0.isUnderMaintenance }
        guard let endpoint = availableEndpoints.randomElement() else {
            throw ServerSelectionError.noEndpoints(.maintenance)
        }

        return Server(logical: server.logical, endpoint: endpoint)
    })

    private static func logicalResolutionFailureReason(
        spec: ConnectionSpec,
        acceptableProtocols: ProtocolSupport,
        baseFilters: [VPNServerFilter]
    ) -> ServerSelectionError.LogicalResolutionFailureReason {
        @Dependency(\.serverRepository) var repository
        let servers = repository.getServers(filteredBy: baseFilters, orderedBy: .none)
        if servers.isEmpty {
            return .locationNotFound(spec.location)
        }

        let serversSupportingFeatures = servers.filter { $0.logical.satisfies(spec.serverFeatureFilter) }
        if serversSupportingFeatures.isEmpty {
            return .featuresNotSupported(spec.features)
        }

        let serversSupportingProtocol = serversSupportingFeatures
            .filter { !$0.protocolSupport.isDisjoint(with: acceptableProtocols) }
        if serversSupportingProtocol.isEmpty {
            return .protocolNotSupported(acceptableProtocols)
        }

        let serversWithoutMaintenance = serversSupportingProtocol.filter { !$0.logical.isUnderMaintenance }
        if serversWithoutMaintenance.isEmpty {
            return .maintenance
        }
        log.assertionFailure("Unexpected logical resolution failure reason")
        return .maintenance
    }
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

    var serverFeatureFilter: VPNServerFilter.ServerFeatureFilter {
        .init(required: requiredFeatureSet, excluded: excludedFeatureSet)
    }

    private var excludedFeatureSet: ServerFeature {
        location.isSecureCore ? .zero : .secureCore
    }

    private var requiredFeatureSet: ServerFeature {
        var requiredFeatures: [ServerFeature] = features
            .compactMap { ServerFeature.init(connectionSpecFeature: $0) }
        if location.isSecureCore {
            requiredFeatures.append(.secureCore)
        }
        return ServerFeature(requiredFeatures)
    }

    var serverTierFilter: VPNServerFilter? {
        switch location {
        case .exact(.free, _, _, _, _):
            return .tier(.max(tier: 0))

        default:
            return nil
        }
    }

    var locationFilters: [VPNServerFilter] {
        switch location {
        case .fastest, .random, .secureCore(.random), .secureCore(.fastest):
            return []

        case .region(let code):
            return [.exitCountryCode(code)]

        case .exact(_, let logicalID, let number, let subRegion, let region):
            return logicalID.map { [.logicalID($0)] } ?? [
                Self.regionFilter(region: region, number: number),
                subRegion.map(VPNServerFilter.city)
            ].compactMap { $0 }

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

extension Domain.Logical {
    func satisfies(_ filter: VPNServerFilter.ServerFeatureFilter) -> Bool {
        feature.isDisjoint(with: filter.excluded) && feature.isSuperset(of: filter.required)
    }
}
