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

import Foundation
import vpncore
import Crypto_VPN

class LocalAgentConnectionMock: LocalAgentConnectionWrapper {
    let clientCertPEM: String
    let clientKeyPEM: String
    let serverCAsPEM: String
    let host: String
    let certServerName: String
    let client: LocalAgentNativeClientProtocol

    var features: LocalAgentFeatures?
    var connectivity: Bool
    var closed: Bool = false

    var state: String = ""
    var status: LocalAgentStatusMessage?

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

    func close() {
        closed = true
    }

    func setConnectivity(_ connectivity: Bool) {
        self.connectivity = connectivity
    }

    func setFeatures(_ features: LocalAgentFeatures?) {
        self.features = features
    }
}

class LocalAgentConnectionMockFactory: LocalAgentConnectionFactory {
    var connectionWasCreated: ((LocalAgentConnectionMock) -> Void)?

    func makeLocalAgentConnection(clientCertPEM: String,
                                  clientKeyPEM: String,
                                  serverCAsPEM: String,
                                  host: String,
                                  certServerName: String,
                                  client: LocalAgentNativeClientProtocol,
                                  features: LocalAgentFeatures?,
                                  connectivity: Bool) throws -> LocalAgentConnectionWrapper {
        let result = LocalAgentConnectionMock(clientCertPEM: clientCertPEM,
                                              clientKeyPEM: clientKeyPEM,
                                              serverCAsPEM: serverCAsPEM,
                                              host: host,
                                              certServerName: certServerName,
                                              client: client,
                                              features: features,
                                              connectivity: connectivity)
        connectionWasCreated?(result)
        return result
    }
}
