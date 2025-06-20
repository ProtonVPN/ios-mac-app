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
struct MapCitiesScreenTests {
    @Shared(.userCountry) var userCountry

//    @Test("Map Screen Cities", arguments: Cities.all)
    @Test("Map Screen Cities", arguments: [("PL", "Warsaw", 52.23, 21.01), ("CH", "Zurich", 47.37, 8.54)])
    @MainActor
    func cities(city: (code: String, cityName: String, lat: Double, long: Double)) {
        let countryCode = city.0
        let store = Store(initialState: HomeMapFeature.State(), reducer: HomeMapFeature.init)
        let size = ViewImageConfig.iPhoneSe.size!
        let mapView = ZStack {
            HomeMapView(store: store, availableHeight: size.height, availableWidth: size.width)
                .frame(size)
                .background(Color(.background))
                .environment(\.colorScheme, .dark)
            VStack {
                Text("\(countryCode), \(city.cityName)")
                    .foregroundStyle(.white)
                    .font(.hero)
                    .padding(.top, .themeSpacing64)
                Spacer()
            }
        }

        withDependencies {
            $0.locale = .en
            $0.date = .constant(Date())
        } operation: {
            $userCountry |=| countryCode
            let actual: VPNConnectionActual = .mock(country: countryCode, coordinates: .init(latitude: city.lat, longitude: city.long))
            store.send(.newMapState(.connectedCoordinates(.init(latitude: city.lat, longitude: city.long), countryCode)))
            store.send(.connectionStateUpdated(.connected(.defaultFastest, actual)))
            assertSnapshot(of: mapView, as: .image(layout: .sizeThatFits), testName: "\(countryCode), \(city.cityName)")
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
            snapshotDirectory = "\(projectDir)/libraries/Home/Tests/HomeSnapshotTests/__Snapshots__/ConnectedCitySnapshots"
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
