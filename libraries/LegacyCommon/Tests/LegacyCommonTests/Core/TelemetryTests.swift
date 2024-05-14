//
//  Created on 20/12/2022.
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
import ProtonCoreNetworking
import XCTest
@testable import LegacyCommon

class TelemetryTests: XCTestCase {
    func testConnectionEventParameters() {
        let request = TelemetryRequest(ConnectionEvent.connectionMock1.toJSONDictionary(), isBusiness: false)
        guard let sut = request.parameters,
              let values = sut["Values"] as? [String: Any],
              let dimensions = sut["Dimensions"] as? [String: Any] else {
            XCTFail("Parameters not in the expected type")
            return
        }
        XCTAssertEqual(sut["MeasurementGroup"] as? String, "vpn.any.connection")
        XCTAssertEqual(sut["Event"] as? String, "vpn_connection")

        XCTAssertEqual(values["time_to_connection"] as? Int, 123000)
        XCTAssertNil(values["session_length"])

        XCTAssertEqual(dimensions["outcome"] as? String, "success")
        XCTAssertEqual(dimensions["user_tier"] as? String, "free")
        XCTAssertEqual(dimensions["vpn_status"] as? String, "on")
        XCTAssertEqual(dimensions["vpn_trigger"] as? String, "country")
        XCTAssertEqual(dimensions["network_type"] as? String, "wifi")
        XCTAssertEqual(dimensions["server_features"] as? String, "")
        XCTAssertEqual(dimensions["vpn_country"] as? String, "CHE")
        XCTAssertEqual(dimensions["user_country"] as? String, "FRA")
        XCTAssertEqual(dimensions["protocol"] as? String, "wireguard_tls")
        XCTAssertEqual(dimensions["server"] as? String, "#IT1")
        XCTAssertEqual(dimensions["port"] as? String, "1234")
        XCTAssertEqual(dimensions["isp"] as? String, "Play")
    }

    func testDisconnectionEventParameters() {
        let request = TelemetryRequest(ConnectionEvent.disconnectionMock1.toJSONDictionary(), isBusiness: false)
        guard let sut = request.parameters,
              let values = sut["Values"] as? [String: Any],
              let dimensions = sut["Dimensions"] as? [String: Any] else {
            XCTFail("Parameters not in the expected type")
            return
        }
        XCTAssertEqual(sut["MeasurementGroup"] as? String, "vpn.any.connection")
        XCTAssertEqual(sut["Event"] as? String, "vpn_disconnection")

        XCTAssertNil(values["time_to_connection"])
        XCTAssertEqual(values["session_length"] as? Int, 123000)

        XCTAssertEqual(dimensions["outcome"] as? String, "success")
        XCTAssertEqual(dimensions["user_tier"] as? String, "paid")
        XCTAssertEqual(dimensions["vpn_status"] as? String, "off")
        XCTAssertEqual(dimensions["vpn_trigger"] as? String, "server")
        XCTAssertEqual(dimensions["network_type"] as? String, "mobile")
        XCTAssertEqual(dimensions["server_features"] as? String, "free,tor,p2p")
        XCTAssertEqual(dimensions["vpn_country"] as? String, "POL")
        XCTAssertEqual(dimensions["user_country"] as? String, "BEL")
        XCTAssertEqual(dimensions["protocol"] as? String, "openvpn_udp")
        XCTAssertEqual(dimensions["server"] as? String, "#PL1")
        XCTAssertEqual(dimensions["port"] as? String, "5678")
        XCTAssertEqual(dimensions["isp"] as? String, "Netia")
    }

    func testUpsellEventParameters() {
        do {
            let request = TelemetryRequest(UpsellEvent.upsellEventDisplayMock.toJSONDictionary(), isBusiness: false)
            checkUpsellEventDimensions(request: request, event: .display, upgradedUserPlan: nil)
        }

        do {
            let request = TelemetryRequest(UpsellEvent.upsellEventUpgradeMock.toJSONDictionary(), isBusiness: false)
            checkUpsellEventDimensions(request: request, event: .upgradeAttempt, upgradedUserPlan: nil)
        }

        do {
            let request = TelemetryRequest(UpsellEvent.upsellEventSuccessMock.toJSONDictionary(), isBusiness: false)
            checkUpsellEventDimensions(request: request, event: .success, upgradedUserPlan: "plus")
        }
    }

    func checkUpsellEventDimensions(request: TelemetryRequest, event: UpsellEvent.Event, upgradedUserPlan: String?) {
        guard let sut = request.parameters,
                  let values = sut["Values"] as? [String: Any],
                  let dimensions = sut["Dimensions"] as? [String: Any] else {
                XCTFail("Parameters not in the expected type")
                return
        }

        XCTAssertEqual(sut["MeasurementGroup"] as? String, "vpn.any.upsell")
        XCTAssertEqual(sut["Event"] as? String, event.rawValue)
        XCTAssertEqual(values.count, 0)
        XCTAssertEqual(dimensions["modal_source"] as? String, "change_server")
        XCTAssertEqual(dimensions["user_plan"] as? String, "free")
        XCTAssertEqual(dimensions["vpn_status"] as? String, "off")
        XCTAssertEqual(dimensions["user_country"] as? String, "ZZ")
        XCTAssertEqual(dimensions["days_since_account_creation"] as? String, "8-14")
        XCTAssertEqual(dimensions["upgraded_user_plan"] as? String?, upgradedUserPlan)
    }

    func testUpsellAccountBuckets() {
        typealias Bucket = UpsellEvent.AccountCreationRangeBucket

        XCTAssertEqual(Bucket(intValue: -1)?.rawValue, nil)
        XCTAssertEqual(Bucket(intValue: 0)?.rawValue, "0")
        XCTAssertEqual(Bucket(intValue: 1)?.rawValue, "1-3")
        XCTAssertEqual(Bucket(intValue: 2)?.rawValue, "1-3")
        XCTAssertEqual(Bucket(intValue: 3)?.rawValue, "1-3")
        XCTAssertEqual(Bucket(intValue: 4)?.rawValue, "4-7")
        XCTAssertEqual(Bucket(intValue: 5)?.rawValue, "4-7")
        XCTAssertEqual(Bucket(intValue: 6)?.rawValue, "4-7")
        XCTAssertEqual(Bucket(intValue: 7)?.rawValue, "4-7")
        XCTAssertEqual(Bucket(intValue: 8)?.rawValue, "8-14")
        XCTAssertEqual(Bucket(intValue: 9)?.rawValue, "8-14")
        XCTAssertEqual(Bucket(intValue: 10)?.rawValue, "8-14")
        XCTAssertEqual(Bucket(intValue: 11)?.rawValue, "8-14")
        XCTAssertEqual(Bucket(intValue: 12)?.rawValue, "8-14")
        XCTAssertEqual(Bucket(intValue: 13)?.rawValue, "8-14")
        XCTAssertEqual(Bucket(intValue: 14)?.rawValue, "8-14")
        XCTAssertEqual(Bucket(intValue: 15)?.rawValue, ">14")
        XCTAssertEqual(Bucket(intValue: 1024)?.rawValue, ">14")
    }
}
