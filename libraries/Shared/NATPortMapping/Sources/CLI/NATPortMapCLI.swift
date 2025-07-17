//
//  Created on 17/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ArgumentParser
import Foundation
@testable import NATPortMapping

@main
struct NATPortMapCLI: AsyncParsableCommand {
    @Flag(help: "UDP is used by default. If specified, TCP will be used instead.")
    var tcp: Bool = false

    @Argument(help: "The gateway address.")
    var gatewayAddress: String = "10.1.0.1"

    @Argument(help: "The local port number.")
    var internalPort: UInt16 = 0

    @Argument(help: "The requested external port.")
    var externalPort: UInt16 = 0

    @Option(help: "The requested lifetime of the NAT port mapping, in seconds.")
    var lifetime: UInt32 = 700
}

extension NATPortMapCLI {
    func run() async throws {
        let client = NATPortMappingClient(gatewayAddress: gatewayAddress)

        let portResponse = try await client.requestPortMapping(
            portProtocol: tcp ? .tcp : .udp,
            internalPort: internalPort,
            externalPort: externalPort,
            lifetime: lifetime
        )
        print("NAT-PMP response: result code: \(portResponse.mappedResultCode), internalPort: \(portResponse.internalPort), externalPort: \(portResponse.mappedExternalPort) lifetime \(portResponse.mappingLifetime)"
        )
        while true {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}
