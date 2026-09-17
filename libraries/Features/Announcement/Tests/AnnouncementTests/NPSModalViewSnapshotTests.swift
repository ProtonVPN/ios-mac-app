//
//  Created on 2026-08-26 by Pawel Jurczyk.
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

@testable import Announcement
import ComposableArchitecture
import SnapshotTesting
import SwiftUI
import System
import Testing
import TestingErgonomics

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct NPSModalViewSnapshotTests {
    #if os(macOS)
        private static let layout = SnapshotEnvironment.Layout.fixed(CGSize(width: 650, height: 550))
    #endif

    @Test("NPSModalView, modal start")
    func npsModalViewModalStart() {
        let view = NPSModalView(
            store: Store(initialState: NPSModalFeature.State()) {
                EmptyReducer()
            }
        )
        .environment(\.colorScheme, .dark)
        #if os(iOS)
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)), named: "iphone")
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPadMini(.landscape(splitView: .full)))), named: "ipad")
        #elseif os(macOS)
            assertSnapshot(of: view, layout: Self.layout, named: "mac")
        #endif
    }

    @Test("NPSModalView, score selected")
    func npsModalViewScoreSelected() {
        let view = NPSModalView(
            store: Store(initialState: NPSModalFeature.State(score: 7)) {
                EmptyReducer()
            }
        )
        .environment(\.colorScheme, .dark)

        #if os(iOS)
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)), named: "iphone")
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPadMini(.landscape(splitView: .full)))), named: "ipad")
        #elseif os(macOS)
            assertSnapshot(of: view, layout: Self.layout, named: "mac")
        #endif
    }

    @Test("NPSModalView, score selected with a comment")
    func npsModalViewScoreSelectedWithComment() {
        let view = NPSModalView(
            store: Store(
                initialState: NPSModalFeature.State(score: 10, comment: "Fast and private.")
            ) {
                EmptyReducer()
            }
        )
        .environment(\.colorScheme, .dark)

        #if os(iOS)
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)), named: "iphone")
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPadMini(.landscape(splitView: .full)))), named: "ipad")
        #elseif os(macOS)
            assertSnapshot(of: view, layout: Self.layout, named: "mac")
        #endif
    }

    @Test("NPSModalView, submitted")
    func npsModalViewSubmitted() {
        let view = NPSModalView(
            store: Store(
                initialState: NPSModalFeature.State(didSubmit: true)
            ) {
                EmptyReducer()
            }
        )
        .environment(\.colorScheme, .dark)

        #if os(iOS)
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)), named: "iphone")
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPadMini(.landscape(splitView: .full)))), named: "ipad")
        #elseif os(macOS)
            assertSnapshot(of: view, layout: Self.layout, named: "mac")
        #endif
    }
}

extension NPSModalViewSnapshotTests: @preconcurrency AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Announcement/Tests/AnnouncementTests/")
    }
}
