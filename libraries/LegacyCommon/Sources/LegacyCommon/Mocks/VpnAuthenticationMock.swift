//
//  VpnAuthenticationMock.swift
//  vpncore - Created on 14.04.2021.
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

#if DEBUG
import Foundation

import Domain
import VPNShared
import VPNSharedTesting

public final class VpnAuthenticationMock: VpnAuthentication {
    public init() { }

    public var loadResult: Result<VpnAuthenticationData, Error> = .success(.mock)
    public var refreshResult: Result<VpnAuthenticationData, Error> = .success(.mock)

    public func loadAuthenticationData(features: VPNConnectionFeatures?, completion: @escaping AuthenticationDataCompletion) {
        completion(loadResult)
    }

    public func refreshCertificates(features: VPNConnectionFeatures?, completion: @escaping CertificateRefreshCompletion) {
        completion(refreshResult)
    }

    public func clearEverything(completion: @escaping (() -> Void)) { completion() }
    
    public func loadClientPrivateKey() -> PrivateKey {
        VpnKeys.mock().privateKey
    }

    public var shouldIgnoreFeatureChanges: Bool { false }
}

fileprivate extension VpnAuthenticationData {
    static var mock: VpnAuthenticationData {
        VpnAuthenticationData(clientKey: VpnKeys.mock().privateKey, clientCertificate: "")
    }
}
#endif
