//
//  Created on 2022-07-01.
//
//  Copyright (c) 2022 Proton AG
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

#if DEBUG
import Foundation
import GoLibs

public class LocalAgentConnectionMock: LocalAgentConnectionWrapper {
    public let clientCertPEM: String
    public let clientKeyPEM: String
    public let serverCAsPEM: String
    public let host: String
    public let certServerName: String
    public let client: LocalAgentNativeClientProtocol

    public var features: LocalAgentFeatures?
    public var connectivity: Bool
    public var closed: Bool = false

    public var state: String = ""
    public var status: LocalAgentStatusMessage?

    private let setterQueue = DispatchQueue(label: "ch.protonvpn.test.local-agent-connection.setter-queue")

    init(clientCertPEM: String,
         clientKeyPEM: String,
         serverCAsPEM: String,
         host: String,
         certServerName: String,
         client: LocalAgentNativeClientProtocol,
         features: LocalAgentFeatures?,
         connectivity: Bool) {
        self.clientCertPEM = clientCertPEM
        self.clientKeyPEM = clientKeyPEM
        self.serverCAsPEM = serverCAsPEM
        self.host = host
        self.certServerName = certServerName
        self.client = client
        self.features = features
        self.connectivity = connectivity
    }

    public func close() {
        setterQueue.sync {
            closed = true
        }
    }

    public func setConnectivity(_ connectivity: Bool) {
        setterQueue.sync {
            self.connectivity = connectivity
        }
    }

    public func setFeatures(_ features: LocalAgentFeatures?) {
        setterQueue.sync {
            self.features = features
        }
    }

    public func sendGetStatus(_: Bool) {

    }
}

public class LocalAgentConnectionMockFactory: LocalAgentConnectionFactory {
    public var connectionWasCreated: ((LocalAgentConnectionMock) -> Void)?

    // swiftlint:disable function_parameter_count
    public func makeLocalAgentConnection(
        clientCertPEM: String,
        clientKeyPEM: String,
        serverCAsPEM: String,
        host: String,
        certServerName: String,
        client: LocalAgentNativeClientProtocol,
        features: LocalAgentFeatures?,
        connectivity: Bool
    ) throws -> LocalAgentConnectionWrapper {
        let result = LocalAgentConnectionMock(
            clientCertPEM: clientCertPEM,
            clientKeyPEM: clientKeyPEM,
            serverCAsPEM: serverCAsPEM,
            host: host,
            certServerName: certServerName,
            client: client,
            features: features,
            connectivity: connectivity
        )
        connectionWasCreated?(result)
        return result
    }
    // swiftlint:enable function_parameter_count

    public init() {}
}
#endif
