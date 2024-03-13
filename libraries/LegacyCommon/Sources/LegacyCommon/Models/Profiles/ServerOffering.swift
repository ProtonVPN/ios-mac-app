//
//  ServerOffering.swift
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
import VPNAppCore
import Persistence
import Dependencies

// This is needed to maintain compatibility with how profiles are stored on disk
// whilst improving them with dynamic server models
public struct ServerWrapper: Codable {
    
    private var _server: ServerModel
    public var server: ServerModel {
        @Dependency(\.serverRepository) var serverRepository: ServerRepository
        if let vpnServer = try? serverRepository.getFirstServer(
            filteredBy: [.logicalID(_server.id)],
            orderedBy: .fastest
        ){
            return ServerModel(server: vpnServer)
        } else {
            return _server
        }
    }
    
    public init(server: ServerModel) {
        _server = server
    }
    
    static func == (lhs: ServerWrapper, rhs: ServerWrapper) -> Bool {
        return lhs.server == rhs.server
    }
}

public enum ServerOffering: Equatable, Codable {
    
    /** Country code or undefined */
    case fastest(String?)
    
    /** Country code or undefined */
    case random(String?)
    
    /** Specific server */
    case custom(ServerWrapper)
    
    public var description: String {
        switch self {
        case .fastest(let cCode):
            return "Fastest server - \(String(describing: cCode))"
        case .random(let cCode):
            return "Random server - \(String(describing: cCode))"
        case .custom(let sModel):
            return "Custom server - \(String(describing: sModel))"
        }
    }
    
    public var countryCode: String? {
        switch self {
        case .fastest(let cCode):
            return cCode
        case .random(let cCode):
            return cCode
        case .custom(let sModel):
            return sModel.server.countryCode
        }
    }
    
    // MARK: - NSCoding
    private struct CoderKey {
        static let serverOffering = "serverOffering"
        static let fastest = "fastest"
        static let random = "random"
        static let custom = "custom"
    }
    
    public init(coder aDecoder: NSCoder) {
        let data = aDecoder.decodeObject(forKey: CoderKey.serverOffering) as! Data
        switch data[0] {
        case 0:
            self = .fastest(aDecoder.decodeObject(forKey: CoderKey.fastest) as? String)
        case 1:
            self = .random(aDecoder.decodeObject(forKey: CoderKey.random) as? String)
        default:
            self = .custom(ServerWrapper(server: aDecoder.decodeObject(forKey: CoderKey.custom) as! ServerModel))
        }
    }
    
    public func encode(with aCoder: NSCoder) {
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
    
    // MARK: - Static functions
    public static func == (lhs: ServerOffering, rhs: ServerOffering) -> Bool {
        var equal: Bool = false
        if case ServerOffering.fastest(let lcc) = lhs, case ServerOffering.fastest(let rcc) = rhs {
            equal = lcc == rcc
        } else if case ServerOffering.random(let lcc) = lhs, case ServerOffering.random(let rcc) = rhs {
            equal = lcc == rcc
        } else if case ServerOffering.custom(let lsw) = lhs, case ServerOffering.custom(let rsw) = rhs {
            equal = lsw.server.id == rsw.server.id
        }
        return equal
    }
}

extension ServerOffering {

    /// Check if offering can find any actually available server/protocol
    public func supports(connectionProtocol: ConnectionProtocol,
                         withCountryGroup grouping: ServerGroupInfo?,
                         smartProtocolConfig: SmartProtocolConfig) -> Bool {
        switch self {
        case .fastest(let countryCode), .random(let countryCode):
            guard let grouping else {
                return true
            }
            assert(grouping.serverOfferingID == countryCode, "Mismatched grouping while checking server protocol support (\(grouping.kind))")

            @Dependency(\.serverRepository) var serverRepository
            let supportedProtocols = connectionProtocol.vpnProtocol != nil
                ? [connectionProtocol.vpnProtocol!]
                : smartProtocolConfig.supportedProtocols

            return !grouping.protocolSupport.isDisjoint(with: ProtocolSupport(vpnProtocols: supportedProtocols))

        case .custom(let wrapper):
            return wrapper.server.supports(connectionProtocol: connectionProtocol,
                                           smartProtocolConfig: smartProtocolConfig)
        }
    }
}

extension ServerGroup {
    public var serverOfferingId: String {
        switch kind {
        case .country(let countryModel):
            return countryModel.countryCode
        case .gateway(let name):
            return "gateway-\(name)"
        }
    }
}

extension ServerGroupInfo {
    public var serverOfferingID: String {
        switch kind {
        case .country(let code):
            return code
        case .gateway(let name):
            return "gateway-\(name)"
        }
    }
}
