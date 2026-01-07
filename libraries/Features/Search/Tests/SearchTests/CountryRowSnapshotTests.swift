//
//  Created on 05/01/2026 by Max Kupetskyi.
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

import Foundation
@testable import Search
import SnapshotTesting
import SwiftUI
import System
import Testing

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct CountryRowSnapshotTests {
    @Test("Dark mode - Normal with all features")
    func countryRowNormalDark() {
        let view = CountryRow(viewModel: CountryViewModelMock.normal)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Dark mode - Upgrade button")
    func countryRowUpgradeDark() {
        let view = CountryRow(viewModel: CountryViewModelMock.upgrade)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Dark mode - Secure Core with icon")
    func countryRowSecureCoreDark() {
        let view = CountryRow(viewModel: CountryViewModelMock.secureCore)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Dark mode - With flag image")
    func countryRowWithFlagDark() {
        let view = CountryRow(viewModel: CountryViewModelMock.withFlag)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Dark mode - No connect button")
    func countryRowNoConnectButtonDark() {
        let view = CountryRow(viewModel: CountryViewModelMock.noConnectButton)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Dark mode - No feature icons")
    func countryRowNoFeatureIconsDark() {
        let view = CountryRow(viewModel: CountryViewModelMock.noFeatureIcons)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Dark mode - With search highlight")
    func countryRowSearchHighlightDark() {
        let view = CountryRow(viewModel: CountryViewModelMock.normal, searchText: "Coun")
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }
}

extension CountryRowSnapshotTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"] {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/Search/Tests/SearchTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
