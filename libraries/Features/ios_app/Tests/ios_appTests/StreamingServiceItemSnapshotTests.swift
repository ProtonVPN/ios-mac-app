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

@testable import ios_app
import LegacyCommon
import SnapshotTesting
import SwiftUI
import Testing

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct StreamingServiceItemSnapshotTests {
    @Test("Streaming service - Netflix")
    func streamingServiceItemNetflix() {
        let view = StreamingServiceItem(
            service: .init(name: "Netflix", icon: "netflix.png")
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 100, height: 80)))
    }

    @Test("Streaming service - Disney+")
    func streamingServiceItemDisneyPlus() {
        let view = StreamingServiceItem(
            service: .init(name: "Disney+", icon: "disney.png")
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 100, height: 80)))
    }

    @Test("Streaming service - HBO Max")
    func streamingServiceItemHBOMax() {
        let view = StreamingServiceItem(
            service: .init(name: "HBO Max", icon: "hbo.png")
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 100, height: 80)))
    }

    @Test("Streaming service - Long name")
    func streamingServiceItemLongName() {
        let view = StreamingServiceItem(
            service: .init(name: "Amazon Prime Video", icon: "amazon.png")
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 100, height: 80)))
    }
}
