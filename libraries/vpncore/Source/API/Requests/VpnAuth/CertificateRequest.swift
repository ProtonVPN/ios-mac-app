//
//  CertificateRequest.swift
//  vpncore - Created on 06.04.2021.
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
//

import Alamofire
import Foundation

// Important! If changing this request, don't forget there is `CertificateRefreshRequest` class that does the same request, but in WireGuard iOS extension.

final class CertificateRequest: BaseRequest {

    let publicKey: PublicKey
    let deviceName: String
    let config: LocalAgentConfiguration

    init(publicKey: PublicKey, config: LocalAgentConfiguration) {
        self.publicKey = publicKey
        self.config = config
        #if os(iOS)
        deviceName = UIDevice.current.name
        #else
        deviceName = Host.current().localizedName ?? ""
        #endif
    }

    // MARK: - Override

    override func path() -> String {
        return super.path() + "/vpn/v1/certificate"
    }

    override var method: HTTPMethod {
        return .post
    }

    override var header: [String: String]? {
        return authenticatedHeader
    }

    override var parameters: [String: Any]? {
        var params = [
            "ClientPublicKey": publicKey.derRepresentation,
            "ClientPublicKeyMode": "EC",
            "DeviceName": deviceName,
            "Mode": "session",
            "Features": config.params
        ] as [String : Any]
        
        if let duration = CertificateConstants.certificateDuration {
            params["Duration"] = duration
        }
        
        return params
    }
}

extension LocalAgentConfiguration {

    var params: [String: Any] {
        var result: [String: Any] = [:]
        result["netshield-level"] = netshield.rawValue
        result["split-tcp"] = vpnAccelerator
        if let bouncing = bouncing {
            result["bouncing"] = bouncing
        }
        return result
    }

}
