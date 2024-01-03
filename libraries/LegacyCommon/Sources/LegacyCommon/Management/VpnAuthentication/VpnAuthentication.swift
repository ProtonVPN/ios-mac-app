//
//  vpnAuthentication.swift
//  vpncore - Created on 06.04.2021.
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

import Domain
import VPNShared

public protocol VpnAuthenticationFactory {
    func makeVpnAuthentication() -> VpnAuthentication
}

public typealias CertificateRefreshCompletion = (Result<VpnAuthenticationData, Error>) -> Void
public typealias AuthenticationDataCompletion = (Result<VpnAuthenticationData, Error>) -> Void

public enum CertificateRefreshError: Error {
    case canceled
}

public enum AuthenticationRemoteClientError: Error {
    case needNewKeys
    case tooManyCertRequests(retryAfter: TimeInterval?)
}

public protocol VpnAuthentication {
    /**
     Refreshes the client certificate if needed
     */
    func refreshCertificates(features: VPNConnectionFeatures?, completion: @escaping CertificateRefreshCompletion)

    /**
     Loads authentication data consisting of private key and client certificate that is needed to connect with a certificate base protocol

     ***Note** The certificate might be expired. The expired certificate still allows to connect to VPN but the app will get jailed and needs to fetch a new certificate with the `refreshCertificates` method

     Takes care of generating the keys if they are missing and refreshing the client certificate if needed.
     */
    func loadAuthenticationData(features: VPNConnectionFeatures?, completion: @escaping AuthenticationDataCompletion)

    /// Loads the client private key needed for establishing a connection. Generates keypair if the keys are missing.
    func loadClientPrivateKey() -> PrivateKey

    /// Deletes all the generated and stored data, so keys and certificate
    func clearEverything(completion: @escaping (() -> Void))

    /// Returns true if certificates managed by this object should be feature-agnostic
    ///
    /// VPN authentication certificates can be embedded with a feature-set. When connecting to a server with such a
    /// certificate, this feature set is applied, without having to rely on Local Agent to manage features separately.
    /// The implementation should only return `true` if Local Agent is guaranteed to always be present to directly
    /// manage features.
    var shouldIgnoreFeatureChanges: Bool { get }
}

public extension VpnAuthentication {
    func refreshCertificates(completion: @escaping CertificateRefreshCompletion) {
        refreshCertificates(features: nil, completion: completion)
    }
    
    func loadAuthenticationData(completion: @escaping AuthenticationDataCompletion) {
        loadAuthenticationData(features: nil, completion: completion)
    }
}
