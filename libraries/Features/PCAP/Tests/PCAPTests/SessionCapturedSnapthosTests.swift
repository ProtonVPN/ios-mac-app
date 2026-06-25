//
//  Created on 2026-06-25 by Pawel Jurczyk.
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

import ComposableArchitecture
@testable import PCAP_iOS
@testable import PCAPShared
import SnapshotTesting
import SwiftUI
import System
import Testing
import TestingErgonomics

@MainActor
@Suite("Session Captured Snapshot Tests", .serialized, .snapshots(record: .missing))
struct SessionCapturedSnapshotsTests {
    @Test
    func `no session`() {
        let view = CaptureVPNSessionView(store: .init(
            initialState: CaptureVPNSessionFeature.State(captureSession: .noSession),
            reducer: EmptyReducer.init
        ))
        .colorScheme(.dark)

        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
    }

    @Test
    func `session started`() {
        let url = URL(filePath: "file.pcap")
        let view = CaptureVPNSessionView(store: .init(
            initialState: CaptureVPNSessionFeature.State(captureSession: .sessionStarted(urlWithDate: .init(url: url, date: .now))),
            reducer: EmptyReducer.init
        ))
        .colorScheme(.dark)

        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
    }

    @Test
    func `session finished`() {
        let url = URL(filePath: "file.pcap")
        let view = SessionCapturedExportView(url: url)
            .colorScheme(.dark)

        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
    }
}

extension SessionCapturedSnapshotsTests: @preconcurrency AssertSnapshot {
    func snapshotDirectory() -> String? {
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/Settings/Tests/PCAPTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
