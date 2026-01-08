//
//  Created on 07/01/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import Announcement
import Clocks
import Dependencies
import Domain
@testable import ios_app
import LegacyCommon
import Persistence
import PersistenceTestSupport
import SnapshotTesting
import SwiftUI
import System
import Testing
import VPNShared

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct CountriesViewSnapshotTests {
    @Test("Countries view - Standard mode with mixed countries")
    func countriesViewStandardMode() {
        withDependencies {
            $0.continuousClock = TestClock()
            $0.serverRepository = .somePlusRecommendedCountries()
        } operation: {
            let viewModel = CountriesViewModelMock.standardMode
            let view = CountriesView(viewModel: viewModel)
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 800)))
        }
    }

    @Test("Countries view - Secure Core mode")
    func countriesViewSecureCoreMode() {
        withDependencies {
            $0.continuousClock = TestClock()
            $0.serverRepository = .somePlusRecommendedCountries()
        } operation: {
            let viewModel = CountriesViewModelMock.secureCoreMode
            let view = CountriesView(viewModel: viewModel)
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 800)))
        }
    }

    @Test("Countries view - With banners")
    func countriesViewWithBanners() {
        withDependencies {
            $0.continuousClock = TestClock()
            $0.serverRepository = .somePlusRecommendedCountries()
            $0.date.now = OfferBannerViewModel.fixedCurrentDate
            $0.locale = Locale(identifier: "en_US_POSIX")
            $0.timeZone = TimeZone(identifier: "UTC")!
        } operation: {
            let viewModel = CountriesViewModelMock.withBanners
            let view = CountriesView(viewModel: viewModel)
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 900)))
        }
    }

    @Test("Countries view - Free user view")
    func countriesViewFreeUser() {
        withDependencies {
            $0.continuousClock = TestClock()
            $0.serverRepository = .somePlusRecommendedCountries()
        } operation: {
            let viewModel = CountriesViewModelMock.freeUser
            let view = CountriesView(viewModel: viewModel)
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 800)))
        }
    }
}

extension CountriesViewSnapshotTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"] {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/ios_app/Tests/ios_appTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
