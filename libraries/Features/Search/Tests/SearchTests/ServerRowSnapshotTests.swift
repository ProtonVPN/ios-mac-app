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
import TestingErgonomics

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct ServerRowSnapshotTests {
    @Test("Normal server with all features")
    func serverRowNormal() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.normal,
            searchText: nil,
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Upgrade button")
    func serverRowUpgrade() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.upgrade,
            searchText: nil,
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Under maintenance")
    func serverRowUnderMaintenance() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.underMaintenance,
            searchText: nil,
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Secure Core without flags")
    func serverRowSecureCore() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.secureCore,
            searchText: nil,
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Secure Core with flags")
    func serverRowSecureCoreWithFlags() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.secureCoreWithFlags,
            searchText: nil,
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Streaming available")
    func serverRowStreaming() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.streaming,
            searchText: nil,
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("High load - red indicator")
    func serverRowHighLoad() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.highLoad,
            searchText: nil,
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Medium load - orange indicator")
    func serverRowMediumLoad() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.mediumLoad,
            searchText: nil,
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Low load - green indicator")
    func serverRowLowLoad() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.lowLoad,
            searchText: nil,
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Translated city name")
    func serverRowTranslatedCity() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.translatedCity,
            searchText: nil,
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("No feature icons")
    func serverRowNoFeatures() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.noFeatures,
            searchText: nil,
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("With search highlight - server name")
    func serverRowSearchHighlightServerName() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.normal,
            searchText: "NY",
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("With search highlight - secure core")
    func serverRowSearchHighlightSecureCore() {
        let view = ServerRow(
            viewModel: ServerViewModelMock.secureCore,
            searchText: "United",
            onStreamingInfoRequested: nil
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }
}

extension ServerRowSnapshotTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/Search/Tests/SearchTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
