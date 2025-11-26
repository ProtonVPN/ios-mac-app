//
//  Created on 21/05/2025 by Max Kupetskyi.
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

@testable import CommonNetworking
@testable import LegacyCommon
import XCTest

final class DefaultPortsDecodingTests: XCTestCase {
    func testDecodeBlackServers() {
        let json = """
        {
            "UDP": [
              80,
              51820,
              4569,
              1194,
              5060
            ],
            "TCP": [
              443,
              7770,
              8443
            ],
            "rand_val_1022020236": 320724099
        }
        """
        let decoder = JSONDecoder.decapitalisingFirstLetter
        guard let object = try? decoder.decode(
            ClientConfigResponse.DefaultPorts.ProtocolPorts.self,
            from: json.data(using: .utf8)!
        ) else {
            XCTFail("ProtocolPorts decoding failed")
            return
        }

        let defaultPorts = ClientConfigResponse.DefaultPorts.ProtocolPorts(udp: [80, 51820, 4569, 1194, 5060], tcp: [443, 7770, 8443], tls: [])
        XCTAssertEqual(defaultPorts, object)
    }

    func testDecodeNormalServers() {
        let json = """
        {
            "UDP": [
              80,
              51820,
              4569,
              1194,
              5060
            ],
            "TCP": [
              443,
              7770,
              8443
            ],
            "TLS": [666]
        }
        """
        let decoder = JSONDecoder.decapitalisingFirstLetter
        guard let object = try? decoder.decode(
            ClientConfigResponse.DefaultPorts.ProtocolPorts.self,
            from: json.data(using: .utf8)!
        ) else {
            XCTFail("ProtocolPorts decoding failed")
            return
        }

        let defaultPorts = ClientConfigResponse.DefaultPorts.ProtocolPorts(udp: [80, 51820, 4569, 1194, 5060], tcp: [443, 7770, 8443], tls: [666])
        XCTAssertEqual(defaultPorts, object)
    }
}
