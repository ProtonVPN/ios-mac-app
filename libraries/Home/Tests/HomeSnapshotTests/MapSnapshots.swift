//
//  Created on 2025-05-27 by Pawel Jurczyk.
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

import SwiftUI
import Testing

import ComposableArchitecture
import SnapshotTesting

import Home
@testable import HomeShared
import Theme
import VPNAppCore

@Suite("Map")
struct MapScreenTests {
    @Shared(.userCountry) var userCountry

    static let allCountries: [String] = ["AD", "AE", "AF", "AG", "AI", "AL", "AM", "AO", "AR", "AS", "AT", "AU", "AW", "AZ", "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BL", "BM", "BN", "BO", "BQ", "BR", "BS", "BT", "BW", "BY", "BZ", "CA", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN", "CO", "CR", "CU", "CV", "CW", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ", "EC", "EE", "EG", "EH", "ER", "ES", "ET", "FI", "FJ", "FK", "FM", "FO", "FR", "GA", "GB", "GD", "GE", "GF", "GG", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GS", "GT", "GU", "GW", "GY", "HK", "HN", "HR", "HT", "HU", "ID", "IE", "IL", "IM", "IN", "IO", "IQ", "IR", "IS", "IT", "JE", "JM", "JO", "JP", "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB", "LC", "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD", "ME", "MF", "MG", "MH", "MK", "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ", "NA", "NC", "NE", "NF", "NG", "NI", "NL", "NO", "NP", "NR", "NU", "NZ", "OM", "PA", "PE", "PF", "PG", "PH", "PK", "PL", "PM", "PN", "PR", "PS", "PT", "PW", "PY", "QA", "RE", "RO", "RS", "RU", "RW", "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SK", "SL", "SM", "SN", "SO", "SR", "SS", "ST", "SV", "SX", "SY", "SZ", "TC", "TD", "TF", "TG", "TH", "TJ", "TK", "TL", "TM", "TN", "TO", "TR", "TT", "TV", "TW", "TZ", "UA", "UG", "US", "UY", "UZ", "VA", "VC", "VE", "VG", "VI", "VN", "VU", "WF", "WS", "YE", "YT", "ZA", "ZM", "ZW"]

    @Test("Map Screen", arguments: allCountries)
    @MainActor
    func countries(countryCode: String) {
        let countryCode = countryCode.uppercased()
        let store = Store(initialState: HomeMapFeature.State(), reducer: HomeMapFeature.init)
        let size = ViewImageConfig.iPhoneSe.size!
        let mapView = ZStack {
            HomeMapView(store: store, availableHeight: size.height, availableWidth: size.width)
                .frame(size)
                .background(Color(.background))
                .environment(\.colorScheme, .dark)
            VStack {
                Text(countryCode)
                    .foregroundStyle(.white)
                    .font(.hero)
                    .padding(.themeSpacing64)
                Spacer()
            }
        }

        withDependencies {
            $0.locale = .en
            $0.date = .constant(Date())
        } operation: {
            $userCountry |=| countryCode
            store.send(.newMapState(.disconnected))
            store.send(.connectionStateUpdated(.disconnected))
            assertSnapshot(of: mapView, as: .image(layout: .sizeThatFits), testName: countryCode)
            $userCountry |=| nil
            store.send(.newMapState(.disconnected))
        }
    }

    private func assertSnapshot<Value>(
        of value: @autoclosure () throws -> Value,
        as snapshotting: Snapshotting<Value, some Any>,
        named name: String? = nil,
        record recording: Bool? = nil,
        timeout: TimeInterval = 5,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        var snapshotDirectory: String?
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"] {
            snapshotDirectory = "\(projectDir)/libraries/Home/Tests/HomeSnapshotTests/__Snapshots__/MapSnapshots"
        }

        let failure = try verifySnapshot(
            of: value(),
            as: snapshotting,
            named: name,
            record: recording,
            snapshotDirectory: snapshotDirectory,
            timeout: timeout,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
        guard let message = failure else { return }
        reportIssue(message, fileID: fileID, filePath: filePath, line: line, column: column)
    }
}
