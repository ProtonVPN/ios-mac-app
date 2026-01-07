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

import Dependencies
import Domain
@testable import ios_app
import Persistence
import PersistenceTestSupport
import SnapshotTesting
import SwiftUI
import System
import Testing
import VPNShared

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct CountryViewSnapshotTests {
    @Test("Country view - Normal country")
    func countryViewNormalCountry() {
        withDependencies {
            $0.serverRepository = .mockWithUSServers()
        } operation: {
            let view = NavigationView {
                CountryView(
                    viewModel: CountryItemViewModel.normalCountry,
                    onDisplayStreamingServices: {}
                )
            }
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 800)))
        }
    }

    @Test("Country view - Plus country")
    func countryViewPlusCountry() {
        withDependencies {
            $0.serverRepository = .mockWithGBServers()
        } operation: {
            let view = NavigationView {
                CountryView(
                    viewModel: CountryItemViewModel.plusCountry,
                    onDisplayStreamingServices: {}
                )
            }
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 800)))
        }
    }

    @Test("Country view - Secure Core")
    func countryViewSecureCore() {
        withDependencies {
            $0.serverRepository = .mockWithCHServers()
        } operation: {
            let view = NavigationView {
                CountryView(
                    viewModel: CountryItemViewModel.secureCoreCountry,
                    onDisplayStreamingServices: {}
                )
            }
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 600)))
        }
    }

    @Test("Country view - Free country")
    func countryViewFreeCountry() {
        withDependencies {
            $0.serverRepository = .mockWithNLServers()
        } operation: {
            let view = NavigationView {
                CountryView(
                    viewModel: CountryItemViewModel.freeCountry,
                    onDisplayStreamingServices: {}
                )
            }
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 600)))
        }
    }

    @Test("Country view - Tor country")
    func countryViewTorCountry() {
        withDependencies {
            $0.serverRepository = .mockWithSEServers()
        } operation: {
            let view = NavigationView {
                CountryView(
                    viewModel: CountryItemViewModel.torCountry,
                    onDisplayStreamingServices: {}
                )
            }
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 600)))
        }
    }
}

extension CountryViewSnapshotTests: AssertSnapshot {
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
