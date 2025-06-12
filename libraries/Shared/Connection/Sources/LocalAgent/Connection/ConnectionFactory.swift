//
//  Created on 03/06/2024.
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

import CasePaths
import Dependencies

import Domain

import protocol GoLibs.LocalAgentNativeClientProtocol
import func GoLibs.LocalAgentNewAgentConnection
import class GoLibs.LocalAgentFeatures

import CoreConnection

typealias ConnectionCreator = @Sendable (ConnectionConfiguration, VPNAuthenticationData, LocalAgentNativeClientProtocol) throws(LAConnectionCreationError) -> LocalAgentConnection

struct ConnectionFactory: DependencyKey {
    var makeLocalAgentConnection: ConnectionCreator

    init(makeLocalAgentConnection: @escaping ConnectionCreator) {
        self.makeLocalAgentConnection = makeLocalAgentConnection
    }
}

struct LAConfiguration: DependencyKey {
    let rootCerts: String
    let localAgentHostname: String

    static var liveValue: LAConfiguration {
        LAConfiguration(
            rootCerts: LAConfiguration.rootCertificates,
            localAgentHostname: LAConfiguration.hostname
        )
    }
}

extension DependencyValues {
    var localAgentConnectionFactory: ConnectionFactory {
        get { self[ConnectionFactory.self] }
        set { self[ConnectionFactory.self] = newValue }
    }

    var localAgentConfiguration: LAConfiguration {
        get { self[LAConfiguration.self] }
        set { self[LAConfiguration.self] = newValue }
    }
}

extension ConnectionFactory {
    static let liveValue = ConnectionFactory(
        makeLocalAgentConnection: { connectionConfiguration, authenticationData, client throws(LAConnectionCreationError) -> LocalAgentConnection in
            @Dependency(\.localAgentConfiguration) var localAgentConfiguration

            var error: NSError?
            let connection = LocalAgentNewAgentConnection(
                authenticationData.clientCertificate,
                authenticationData.clientKey.derRepresentation,
                localAgentConfiguration.rootCerts,
                localAgentConfiguration.localAgentHostname,
                connectionConfiguration.hostname,
                client,
                LocalAgentFeatures.from(connectionFeatures: connectionConfiguration.features),
                true,
                &error
            )

            if let error {
                // This will usually be "tls: private key does not match public key"
                // For more information about possible errors, check the Go crypto/tls library.
                // If an error is thrown here, it's unlikely we can connect without first regenerating our key&cert.
                if let tlsError = GoTLSError(error: error) {
                    throw .goTLSError(tlsError, underlyingError: error)
                } else {
                    throw .unknownError(error)
                }
            }

            guard let connection else {
                log.assertionFailure("LocalAgentNewAgentConnection should have returned an error")
                throw .connectionObjectMissing
            }

            return connection
        }
    )
}

extension LocalAgentFeatures {
    enum Keys: String {
        case vpnAccelerator = "split-tcp"
        case netShield = "netshield-level"
        case jailed = "jail"
        case natType = "randomized-nat"
        case bouncing
        case safeMode = "safe-mode"
    }

    func set(feature: ConnectionFeatureChange.AgentFeature) {
        switch feature {
        case let .moderateNAT(value):
            setBool(Keys.natType.rawValue, value: value.flag)
        case let .netShield(netShieldType):
            setInt(Keys.netShield.rawValue, value: Int64(netShieldType.rawValue))
        case let .vpnAccelerator(value):
            setBool(Keys.vpnAccelerator.rawValue, value: value)
        }
    }

    static func from(featureSet features: Set<ConnectionFeatureChange.AgentFeature>) -> LocalAgentFeatures? {
        let featuresObject = LocalAgentFeatures()
        features.forEach {
            featuresObject?.set(feature: $0)
        }
        return featuresObject
    }

    static func from(connectionFeatures: VPNConnectionFeatures) -> LocalAgentFeatures? {
        let featuresObject = LocalAgentFeatures()
        featuresObject?.setInt(Keys.netShield.rawValue, value: Int64(connectionFeatures.netshield.rawValue))
        featuresObject?.setBool(Keys.vpnAccelerator.rawValue, value: connectionFeatures.vpnAccelerator)
        connectionFeatures.bouncing.map { featuresObject?.setString(Keys.bouncing.rawValue, value: $0) }
        featuresObject?.setBool(Keys.natType.rawValue, value: connectionFeatures.natType.flag)
        connectionFeatures.safeMode.map { featuresObject?.setBool(Keys.safeMode.rawValue, value: $0) }
        return featuresObject
    }
}

@CasePathable
public enum LAConnectionCreationError: Error {
    /// We're most likely connecting with mismatched/malformed keys or certificates. This indicates we tried to connect
    /// with malformed/mismatched certificates/keys.
    case goTLSError(GoTLSError, underlyingError: Error)

    /// ``LocalAgentNewAgentConnection`` returned an unexpected non-crypto/tls error. We need to add this error to our
    /// `GoTLSError` enum.
    case unknownError(Error)

    /// ``LocalAgentNewAgentConnection`` did not return a connection object, or an error. Should never happen.
    case connectionObjectMissing
}

extension LAConnectionCreationError: ProtonVPNError {
    public static let errorDomain = "LocalAgentConnectionCreationErrorDomain"

    public var charCode: FourCharCode {
        switch self {
        case .connectionObjectMissing:
            return "LACO"
        case let .goTLSError(goTLSError, _):
            return goTLSError.charCode
        case .unknownError:
            return "LACU"
        }
    }

    public var underlyingError: (any Error)? {
        switch self {
        case let .goTLSError(_, underlyingError):
            return underlyingError

        case let .unknownError(error):
            return error

        case .connectionObjectMissing:
            return nil
        }
    }
}

/// Whenever a new error is seen in the wild, and we want to handle it differently/track it, add it here.
/// Possible errors can be found at [tls.go](https://cs.opensource.google/go/go/+/master:src/crypto/tls/tls.go;l=267)
/// In theory, *none* of these should ever be encountered - if they are, we're connecting with mismatched/malformed
/// keys or certificates, and this is indicative of a different problem earlier in the connection process
@CasePathable
public enum GoTLSError: Error {
    /// Thrown when a previous user's key is used to connect with the current user's certificate, and vice-versa.
    case privateKeyDoesNotMatchPublicKey
}

extension GoTLSError: ProtonVPNError {
    private static let privateKeyDoesNotMatchPublicKeyErrorDescription: String = "tls: private key does not match public key"

    public static let errorDomain = "GoTLSErrorDomain"

    init?(error: NSError) {
        guard let localizedDescription = error.userInfo[NSLocalizedDescriptionKey] as? String else { return nil }

        switch localizedDescription {
        case Self.privateKeyDoesNotMatchPublicKeyErrorDescription:
            self = .privateKeyDoesNotMatchPublicKey
        default:
            return nil
        }
    }

    public var charCode: FourCharCode {
        switch self {
        case .privateKeyDoesNotMatchPublicKey:
            return "GTNM"
        }
    }
}
