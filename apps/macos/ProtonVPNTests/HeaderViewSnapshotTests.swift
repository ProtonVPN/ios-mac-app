//
//  Created on 11/08/2026 by Max Kupetskyi.
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

import AppKit
import ComposableArchitecture
import Connection
import Dependencies
import Domain
import Foundation
@testable import ProtonVPN
import Sharing
import SnapshotTesting
import SwiftUI
import System
import Testing
import TestingErgonomics
import VPNAppCore
import VPNShared

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct HeaderViewSnapshotTests {
    private let snapshotSize = CGSize(width: 340, height: 200)
    private let now = SnapshotEnvironment.date

    @Test("Disconnected", arguments: Appearance.allCases)
    func disconnected(appearance: Appearance) {
        assert(appearance: appearance) { _ in }
    }

    @Test("Connected", arguments: Appearance.allCases)
    func connected(appearance: Appearance) {
        assert(appearance: appearance, connectionState: .snapshotConnected) {
            $0.bitrate = Bitrate(download: 31 * 1024, upload: 782 * 1024)
        }
    }

    @Test("Connected on a free plan", arguments: Appearance.allCases)
    func connectedOnFreePlan(appearance: Appearance) {
        assert(appearance: appearance, connectionState: .snapshotConnected, userTier: .free) {
            $0.bitrate = Bitrate(download: 31 * 1024, upload: 782 * 1024)
        }
    }

    @Test("Change server counting down", arguments: Appearance.allCases)
    func changeServerCountingDown(appearance: Appearance) {
        assert(appearance: appearance, connectionState: .snapshotConnected, userTier: .free) { [now] in
            $0.bitrate = Bitrate(download: 31 * 1024, upload: 782 * 1024)
            $0.serverChangeAvailability = .unavailable(
                until: now.addingTimeInterval(90),
                duration: 90,
                exhaustedSkips: false
            )
        }
    }

    @Test("Port forwarding", arguments: Appearance.allCases)
    func portForwarding(appearance: Appearance) {
        assert(appearance: appearance, connectionState: .snapshotConnected) {
            $0.bitrate = Bitrate(download: 31 * 1024, upload: 782 * 1024)
            $0.mappedPort = 36528
        }
    }

    @Test("Announcements bell", arguments: Appearance.allCases)
    func announcementsBell(appearance: Appearance) {
        assert(appearance: appearance, connectionState: .snapshotConnected) {
            $0.bitrate = Bitrate(download: 31 * 1024, upload: 782 * 1024)
            $0.bell = HeaderFeature.Bell(iconURL: nil, tooltip: "Offer", hasUnread: true)
        }
    }

    @Test("Advanced kill switch blocking", arguments: Appearance.allCases)
    func advancedKillSwitchBlocking(appearance: Appearance) {
        assert(appearance: appearance, connectionState: .snapshotKillSwitchActive) { _ in }
    }

    @Test("Authentication required", arguments: Appearance.allCases)
    func authenticationRequired(appearance: Appearance) {
        assert(appearance: appearance, connectionState: .snapshotAuthenticationRequired) { _ in }
    }

    // MARK: - Private

    enum Appearance: String, CaseIterable {
        case light
        case dark

        var name: NSAppearance.Name {
            self == .dark ? .darkAqua : .aqua
        }
    }

    private func assert(
        appearance: Appearance,
        connectionState: ConnectionState = .disconnected,
        userTier: VpnTier = .paid,
        state configure: (inout HeaderFeature.State) -> Void,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        withDependencies {
            $0.defaultAppStorage = UserDefaults(suiteName: "HeaderViewSnapshotTests-\(UUID().uuidString)")!
            $0.date = .constant(now)
        } operation: {
            @Shared(.connectionState) var sharedConnectionState
            @Shared(.userTier) var sharedUserTier
            $sharedConnectionState.withLock { $0 = connectionState }
            $sharedUserTier.withLock { $0 = userTier }

            var state = HeaderFeature.State()
            configure(&state)

            let (window, size) = makeWindow(state: state, appearance: appearance.name)
            assertSnapshot(
                of: window.contentView!,
                as: .image(size: size),
                named: appearance.rawValue,
                fileID: fileID,
                file: file,
                testName: testName,
                line: line,
                column: column
            )
        }
    }

    private func makeWindow(
        state: HeaderFeature.State,
        appearance: NSAppearance.Name
    ) -> (window: NSWindow, size: CGSize) {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: appearance)

        let store = StoreOf<HeaderFeature>(initialState: state) {
            EmptyReducer()
        }
        let viewController = NSHostingController(rootView: HeaderView(store: store))
        let needed = viewController.sizeThatFits(in: CGSize(width: snapshotSize.width, height: 0))
        let size = CGSize(
            width: snapshotSize.width,
            height: max(snapshotSize.height, needed.height)
        )

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.contentViewController = viewController
        window.setContentSize(size)
        window.layoutIfNeeded()
        viewController.view.layoutSubtreeIfNeeded()

        return (window, viewController.view.bounds.size)
    }
}

extension HeaderViewSnapshotTests: @preconcurrency AssertSnapshot {
    func snapshotDirectory() -> String? {
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/apps/macos/ProtonVPNTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}

private extension ConnectionState {
    static let snapshotConnected: ConnectionState = .connected(
        .init(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: ["peer-id"], killSwitch: false),
        .init(
            currentPeer: VPNConnectionActual.mock().server,
            connectionDate: SnapshotEnvironment.date,
            protocolConnectionData: .proTUN(.init(transport: .udp, serverExitV4: "185.159.157.200"))
        )
    )

    static let snapshotKillSwitchActive: ConnectionState = .killSwitchActive(
        .defaultFastest,
        .init(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: [], killSwitch: true)
    )

    static let snapshotAuthenticationRequired: ConnectionState = .authenticationRequired(
        .resolved(.init(
            spec: .defaultFastest,
            tunnelProtocol: .wireGuard,
            resolvedServer: VPNConnectionActual.mock().server
        )),
        tunnelActive: true
    )
}
