//
//  Created on 25/03/2026 by Max Kupetskyi.
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
import Countries
import Dependencies
import Domain
import LegacyCommon
import Sharing
import SnapshotTesting
import System
import Testing
import TestingErgonomics

@testable import ProtonVPN

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct CountriesSectionViewControllerSnapshotTests {
    private let snapshotSize = CGSize(width: 360, height: 800)
    private let snapshotCountryCodes = ["SE", "CH", "DE", "NL", "US", "JP", "GB", "FR", "CA", "AU", "ES", "IT"]

    @Test("Countries screen", arguments: ["light", "dark"])
    func countriesScreen(appearance: String) async {
        @Shared(.secureCoreToggle) var secureCoreToggle = false
        @Shared(.userTier) var userTier: Int? = .paidTier
        let appearanceName: NSAppearance.Name = appearance == "dark" ? .darkAqua : .aqua
        withMockedDeps {
            let (viewController, window) = makeViewController(appearance: appearanceName)
            viewController.view.layoutSubtreeIfNeeded()

            assertSnapshot(
                of: window.contentView!,
                as: .image(size: snapshotSize),
                named: appearance
            )
        }
    }

    @Test("Countries screen free tier", arguments: ["light", "dark"])
    func countriesScreenFreeTier(appearance: String) async {
        @Shared(.secureCoreToggle) var secureCoreToggle = false
        @Shared(.userTier) var userTier: Int? = .freeTier
        let appearanceName: NSAppearance.Name = appearance == "dark" ? .darkAqua : .aqua
        withMockedDeps {
            let (viewController, window) = makeViewController(appearance: appearanceName)
            viewController.view.layoutSubtreeIfNeeded()

            assertSnapshot(
                of: window.contentView!,
                as: .image(size: snapshotSize),
                named: appearance
            )
        }
    }

    // MARK: - Private

    private func makeViewController(appearance: NSAppearance.Name) -> (CountriesSectionViewController, NSWindow) {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: appearance)

        let viewModel = CountriesSectionViewModel(factory: DependencyFactory())
        let viewController = CountriesSectionViewController(viewModel: viewModel)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: snapshotSize),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.contentViewController = viewController
        viewController.view.frame = window.contentView?.bounds ?? CGRect(origin: .zero, size: snapshotSize)
        forceLoadedState(in: viewModel.store)
        window.layoutIfNeeded()
        viewController.view.layoutSubtreeIfNeeded()

        return (viewController, window)
    }

    private func forceLoadedState(in store: StoreOf<CountriesListFeature>) {
        let groups = makeSnapshotServerGroups()
        let countries = groups.compactMap { group -> CityStateListFeature.State? in
            switch group.kind {
            case .country:
                .init(groupInfo: group, search: "", expandedCode: nil, secureCore: false)
            default:
                nil
            }
        }
        let gateways = groups.compactMap { group -> CityStateListFeature.State? in
            switch group.kind {
            case .gateway:
                .init(groupInfo: group, search: "", expandedCode: nil, secureCore: false)
            default:
                nil
            }
        }
        store.send(.loadingFinished(
            countries: .init(uniqueElements: countries),
            gateways: .init(uniqueElements: gateways)
        ))
    }

    private func withMockedDeps<T>(_ operation: () -> T) -> T {
        let serverGroups = makeSnapshotServerGroups()
        return withDependencies {
            $0.mainQueue = .immediate
            // Keeping the same full serverRepository signature avoids linker issues in tests.
            $0.serverRepository = .init(
                serverCount: { 0 },
                countryCount: { 0 },
                upsertServers: { _ in },
                deleteServers: { _, _ in 0 },
                upsertLoads: { _ in },
                groups: { _, _, _ in serverGroups },
                servers: { _, _ in [] },
                server: { _, _ in nil },
                getMetadata: { _ in nil },
                setMetadata: { _, _ in },
                closeConnection: {}
            )
            $0.vpnStateConfiguration = .init(
                determineActiveVpnProtocolSync: { _, _ in },
                determineActiveVpnProtocol: { _ in nil },
                determineActiveVpnStateSync: { _, _ in },
                determineActiveVpnState: { _ in (NEVPNManagerMock(), .disconnected) },
                determineNewState: { _ in .disconnected },
                getInfoSync: { _ in },
                getInfo: { VpnStateConfigurationInfo(state: .disconnected, hasConnected: false, connection: nil) }
            )
        } operation: {
            operation()
        }
    }

    private func makeSnapshotServerGroups() -> [ServerGroupInfo] {
        snapshotCountryCodes.enumerated().map { index, code in
            .init(
                kind: .country(code: code),
                featureIntersection: .zero,
                featureUnion: index.isMultiple(of: 2) ? [.p2p] : [.tor],
                minTier: .paidTier,
                maxTier: .paidTier,
                serverCount: 8 + index,
                cityCount: 2,
                latitude: 0,
                longitude: 0,
                supportsSmartRouting: true,
                isUnderMaintenance: false,
                protocolSupport: .all
            )
        }
    }
}

extension CountriesSectionViewControllerSnapshotTests: @preconcurrency AssertSnapshot {
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
