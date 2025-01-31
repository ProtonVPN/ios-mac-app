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

import Dependencies

import Domain

import protocol GoLibs.LocalAgentNativeClientProtocol
import func GoLibs.LocalAgentNewAgentConnection
import class GoLibs.LocalAgentFeatures

import CoreConnection

typealias ConnectionCreator = @Sendable (ConnectionConfiguration, VPNAuthenticationData, LocalAgentNativeClientProtocol) throws -> LocalAgentConnection

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
        makeLocalAgentConnection: { connectionConfiguration, authenticationData, client in
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
                throw error
            }

            guard let connection else {
                log.assertionFailure("LocalAgentNewAgentConnection should have returned an error")
                throw LocalAgentError.serverError
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
        case .moderateNAT(let value):
            setBool(Keys.natType.rawValue, value: value.flag)
        case .netShield(let netShieldType):
            setInt(Keys.netShield.rawValue, value: Int64(netShieldType.rawValue))
        case .vpnAccelerator(let value):
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
