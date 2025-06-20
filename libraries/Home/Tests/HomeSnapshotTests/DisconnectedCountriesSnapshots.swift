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
struct DisconnectedCountriesSnapshotsTests {
    @Shared(.userCountry) var userCountry

//    @Test("Map Screen Countries", arguments: Countries.all)
    @Test("Map Screen Countries", arguments: ["PL", "CH"])
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
            snapshotDirectory = "\(projectDir)/libraries/Home/Tests/HomeSnapshotTests/__Snapshots__/DisconnectedCountriesSnapshots"
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
