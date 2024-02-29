//
//  VpnServerSelector.swift
//  vpncore - Created on 2020-06-01.
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
//

import Foundation

import Dependencies

import Ergonomics
import Domain

import Persistence
import VPNAppCore

/// Selects the most suitable server to connect to
///
/// - Note: Does not select gateway servers unless the request explicitly specified a gateway server using
/// `CountryConnectionRequestType.server)`
class VpnServerSelector {
    @Dependency(\.serverRepository) var repository

    // Callbacks
    public var changeActiveServerType: ((_ serverType: ServerType) -> Void)?
    public var getCurrentAppState: AppStateGetter
    public var notifyResolutionUnavailable: ResolutionNotification?
    typealias AppStateGetter = (() -> AppState)
    typealias ResolutionNotification = ((_ forSpecificCountry: Bool, _ type: ServerType, _ reason: ResolutionUnavailableReason) -> Void)
    
    // Settings for selection
    private var serverTypeToggle: ServerType
    private var userTier: Int
    private var connectionProtocol: ConnectionProtocol
    private var smartProtocolConfig: SmartProtocolConfig
    
    public init(
        serverType: ServerType,
        userTier: Int,
        connectionProtocol: ConnectionProtocol,
        smartProtocolConfig: SmartProtocolConfig,
        appStateGetter: @escaping AppStateGetter
    ) {
        self.serverTypeToggle = serverType
        self.userTier = userTier
        self.getCurrentAppState = appStateGetter
        self.connectionProtocol = connectionProtocol
        self.smartProtocolConfig = smartProtocolConfig
    }

    private var supportedProtocols: ProtocolSupport {
        switch connectionProtocol {
        case .vpnProtocol(let vpnProtocol):
            return vpnProtocol.protocolSupport
        case .smartProtocol:
            return smartProtocolConfig.supportedProtocols
                .reduce(.zero, { $0.union($1.protocolSupport) })
        }
    }

    private var supportsCurrentProtocol: VPNServerFilter {
        return .supports(protocol: supportedProtocols)
    }

    /// Returns a server that best suits connection request
    public func selectServer(connectionRequest: ConnectionRequest) -> ServerModel? {
        // use the ui to determine connection type if unspecified
        let type = connectionRequest.serverType == .unspecified ? serverTypeToggle : connectionRequest.serverType

        let baseFilters = connectionRequest.locationFilters + [type.serverFilter]
        let order: VPNServerOrder = connectionRequest.ordering

        // Additional filters that make the query blazingly fast by letting us determine if there is a single best
        // server to connect to. If not, we can run the query again without these to determine the unavailability reason
        let additionalFilters = [supportsCurrentProtocol, .tier(.max(tier: userTier)), .isNotUnderMaintenance]

        let filters = baseFilters + additionalFilters

        log.info(
            "Selecting server",
            category: .persistence,
            metadata: [
                "connectionRequest": "\(connectionRequest)",
                "filters": "\(filters)",
                "order": "\(order)"
            ]
        )

        do {
            let result = try repository.getFirstServer(filteredBy: filters, orderedBy: order)

            guard let server = result else {
                log.error("No servers satisfy requested criteria", category: .persistence)

                determineAndNotifyUnavailabilityReason(
                    forSpecificCountry: true,
                    type: type,
                    baseFilters: baseFilters
                )
                return nil
            }

            changeActiveServerType?(type)
            return ServerModel(server: server)
        } catch {
            log.error("Failed to select server", category: .persistence, metadata: ["error": "\(error)"])
            return nil
        }
    }


    private func determineAndNotifyUnavailabilityReason(
        forSpecificCountry: Bool,
        type: ServerType,
        baseFilters: [VPNServerFilter]
    ) {
        do {
            let servers = try repository.getServers(filteredBy: baseFilters, orderedBy: .none)

            // If servers are already empty, we will return `protocolNotSupported` unless we add a new `locationNotFound`

            let serversSupportingProtocol = servers.filter { !$0.protocolSupport.isDisjoint(with: supportedProtocols) }
            if serversSupportingProtocol.isEmpty {
                notifyResolutionUnavailable?(forSpecificCountry, type, .protocolNotSupported)
                return
            }

            let serversNotRequiringUpgrade = serversSupportingProtocol.filter { userTier >= $0.logical.tier }
            if serversNotRequiringUpgrade.isEmpty {
                let lowestTier = serversSupportingProtocol.map(\.logical.tier).min() ?? CoreAppConstants.VpnTiers.visionary
                notifyResolutionUnavailable?(forSpecificCountry, type, .upgrade(lowestTier))
                return
            }

            let serversWithoutMaintenance = serversNotRequiringUpgrade.filter { $0.logical.status != 0 }
            if serversWithoutMaintenance.isEmpty {
                notifyResolutionUnavailable?(forSpecificCountry, type, .maintenance)
                return
            }

        } catch {
            log.error(
                "Failed to retrieve servers while determining unavailability reason",
                category: .persistence,
                metadata: ["error": "\(error)"]
            )
        }
    }
    
}

extension ConnectionRequest {

    var locationFilters: [VPNServerFilter] {
        switch connectionType {
        case .country(let countryCode, .fastest), .country(let countryCode, .random):
            return [.kind(.country(code: countryCode))] // inherently excludes gateways

        case .country(_, .server(let model)):
            return [.logicalID(model.id)]

        case .city(let countryCode, let city):
            return [.kind(.country(code: countryCode)), .city(city)]

        case .fastest, .random:
            // Exclude gateways. We could also use the .kind(.country) filter for this purpose.
            return [.features(.init(required: .zero, excluded: .restricted))]
        }
    }

    var ordering: VPNServerOrder {
        switch connectionType {
        case .country(_, let requestType):
            switch requestType {
            case .fastest:
                return .fastest
            case .random:
                return .random
            case .server:
                return .fastest
            }

        case .city(_, _):
            return .fastest

        case .fastest:
            return .fastest

        case .random:
            return .random
        }
    }
}
