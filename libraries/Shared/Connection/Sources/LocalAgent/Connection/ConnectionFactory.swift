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

import protocol GoLibs.LocalAgentNativeClientProtocol
import func GoLibs.LocalAgentNewAgentConnection
import func GoLibs.LocalAgentNewFeatures

import ConnectionFoundations

struct ConnectionFactory: DependencyKey {
    var makeLocalAgentConnection: @Sendable (
        ConnectionConfiguration,
        VPNAuthenticationData,
        LocalAgentNativeClientProtocol
    ) throws -> LocalAgentConnection
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
    static var liveValue = ConnectionFactory(
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
                LocalAgentNewFeatures(),
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
