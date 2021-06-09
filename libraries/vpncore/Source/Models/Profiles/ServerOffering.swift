//
//  ServerOffering.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

// This is needed to maintain compatibility with how profiles are stored on disk
// whilst improving them with dynamic server models
public struct ServerWrapper {
    
    private var _server: ServerModel
    public var server: ServerModel {
        if let latestServerModel = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary, serverStorage: ServerStorageConcrete()).servers.first(where: { (serverModel) -> Bool in
            return _server == serverModel
        }) {
            return latestServerModel
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

public enum ServerOffering {
    
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
        var data = Data(count: 1)
        switch self {
        case .fastest(let ccode):
            data[0] = 0
            aCoder.encode(ccode, forKey: CoderKey.fastest)
        case .random(let ccode):
            data[0] = 1
            aCoder.encode(ccode, forKey: CoderKey.random)
        case .custom(let swrapper):
            data[0] = 2
            aCoder.encode(swrapper.server, forKey: CoderKey.custom)
        }
        aCoder.encode(data, forKey: CoderKey.serverOffering)
    }
    
    // MARK: - Static functions
    public static func == (lhs: ServerOffering, rhs: ServerOffering) -> Bool {
        var equal: Bool = false
        if case ServerOffering.fastest(let lcc) = lhs, case ServerOffering.fastest(let rcc) = rhs {
            equal = lcc == rcc
        } else if case ServerOffering.random(let lcc) = lhs, case ServerOffering.random(let rcc) = rhs {
            equal = lcc == rcc
        } else if case ServerOffering.custom(let lsw) = lhs, case ServerOffering.custom(let rsw) = rhs {
            equal = lsw == rsw
        }
        return equal
    }
}
