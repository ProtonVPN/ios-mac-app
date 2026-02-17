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

@testable import ios_app
import SnapshotTesting
import SwiftUI
import System
import Testing
import TestingErgonomics

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct BannerViewSnapshotTests {
    @Test("Upsell banner with worldwide coverage")
    func bannerViewUpsellBanner() {
        let view = BannerView(viewModel: BannerViewModel.upsellBanner)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 100)))
    }

    @Test("Banner with short text")
    func bannerViewShortText() {
        let view = BannerView(viewModel: BannerViewModel.shortText)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 100)))
    }

    @Test("Banner with long text")
    func bannerViewLongText() {
        let view = BannerView(viewModel: BannerViewModel.longText)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 120)))
    }

    @Test("Banner with custom icon")
    func bannerViewCustomIcon() {
        let view = BannerView(viewModel: BannerViewModel.customIcon)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 100)))
    }
}

extension BannerViewSnapshotTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/ios_app/Tests/ios_appTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
