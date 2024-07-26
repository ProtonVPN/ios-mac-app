//
//  Created on 09/02/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import XCTest

import Dependencies

import Domain
import Persistence
import LegacyCommon
import Search
@testable import ProtonVPN

final class CountriesViewModelTests: XCTestCase {
    var mockPropertiesManager: PropertiesManagerMock!

    override func setUp() {
        super.setUp()
        mockPropertiesManager = PropertiesManagerMock()
        mockPropertiesManager.smartProtocolConfig = .init(openVPN: true, iKEv2: true, wireGuardUdp: true, wireGuardTcp: true, wireGuardTls: true)
    }

    var mockFactory: DependencyFactory {
        return DependencyFactory(propertiesManager: mockPropertiesManager)
    }

    var mockGateway: VpnGatewayProtocol {
        let gateway = VpnGatewayMock(propertiesManager: mockPropertiesManager, activeServerType: .unspecified, connection: .disconnected)
        gateway._userTier = 3
        return gateway
    }

    var serverGroups: [ServerGroupInfo]!

    func withMockedRepository<T>(_ operation: () -> T) -> T {
        return withDependencies {
            // Normally we would be able to omit all arguments except groups, but doing so triggers a linker bug with XCTDynamicOverlay.
            $0.serverRepository = .init(
                serverCount: { 0 },
                countryCount: { 0 },
                upsertServers: { _ in },
                server: { _, _ in nil },
                servers: { _, _ in [] },
                deleteServers: { _, _ in 0 },
                upsertLoads: { _ in },
                groups: { _, _ in self.serverGroups },
                getMetadata: { _ in nil },
                setMetadata: { _, _ in },
                closeConnection: { }
            )
        } operation: {
            operation()
        }
    }

    func makeViewModel() -> CountriesViewModel {
        withMockedRepository {
            CountriesViewModel(
                factory: mockFactory,
                vpnGateway: mockGateway,
                countryService: CountryServiceMock()
            )
        }
    }

    func testConnectionProtocolChangedUpdatesCountryItems() {
        // Start off with smart protocol enabled and all protocols supported
        mockPropertiesManager.connectionProtocol = .smartProtocol
        serverGroups = [MockServerGroup.dev, MockServerGroup.sweden, MockServerGroup.switzerland]

        let sut = makeViewModel()

        // All server groups provide at least one supported protocol
        XCTAssertEqual(sut.numberOfSections(), 2) // gateways, all locations
        XCTAssertEqual(sut.numberOfRows(in: 0), 1) // dev
        assert(sut.cellModel(for: 0, in: 0), isServerGroupOfKind: .gateway(name: "Dev"), isUnderMaintenance: false)
        XCTAssertEqual(sut.numberOfRows(in: 1), 2) // sweden, switzerland
        assert(sut.cellModel(for: 0, in: 1), isServerGroupOfKind: .country(code: "SE"), isUnderMaintenance: false)
        assert(sut.cellModel(for: 1, in: 1), isServerGroupOfKind: .country(code: "CH"), isUnderMaintenance: false)

        // Now let's update our protocol to WireGuard UDP
        mockPropertiesManager.connectionProtocol = .vpnProtocol(.wireGuard(.udp))
        withMockedRepository {
            NotificationCenter.default.post(name: PropertiesManager.vpnProtocolNotification, object: nil)
        }

        // Switzerland should be placed under maintenance (it only supports ike)
        assert(sut.cellModel(for: 1, in: 1), isServerGroupOfKind: .country(code: "CH"), isUnderMaintenance: true)

        // Finally, let's try changing our protocol to Stealth
        mockPropertiesManager.connectionProtocol = .vpnProtocol(.wireGuard(.tls))
        withMockedRepository {
            NotificationCenter.default.post(name: PropertiesManager.vpnProtocolNotification, object: nil)
        }

        // Dev gateway should be placed under maintenance as well - it doesn't support stealth
        assert(sut.cellModel(for: 0, in: 0), isServerGroupOfKind: .gateway(name: "Dev"), isUnderMaintenance: true)
    }

    private func assert(_ rowVM: RowViewModel, isServerGroupOfKind kind: ServerGroupInfo.Kind, isUnderMaintenance: Bool) {
        guard case .serverGroup(let viewModel) = rowVM else {
            XCTFail("Expected row view model to be a server group, but found: \(rowVM)")
            return
        }
        XCTAssertEqual(viewModel.serversGroup.kind, kind)
        XCTAssertEqual(viewModel.underMaintenance, isUnderMaintenance)
    }
}

class DependencyFactory: CountriesViewModel.Factory {
    let propertiesManager: PropertiesManagerProtocol

    init(propertiesManager: PropertiesManagerMock) {
        self.propertiesManager = propertiesManager
    }

    func makeAnnouncementManager() -> AnnouncementManager { AnnouncementManagerMock() }
    func makeAppStateManager() -> AppStateManager { AppStateManagerMock() }
    func makeCoreAlertService() -> CoreAlertService { AlertServiceEmptyStub() }
    func makeNATTypePropertyProvider() -> NATTypePropertyProvider { NATTypePropertyProviderMock() }
    func makeNetShieldPropertyProvider() -> NetShieldPropertyProvider { NetShieldPropertyProviderMock() }
    func makePropertiesManager() -> PropertiesManagerProtocol { propertiesManager }
    func makeSafeModePropertyProvider() -> SafeModePropertyProvider { SafeModePropertyProviderMock() }
    func makeVpnKeychain() -> VpnKeychainProtocol { VpnKeychainMock(maxTier: .paidTier) }
    func makeConnectionStatusService() -> ConnectionStatusService { ConnectionStatusServiceMock() }
    func makePlanService() -> PlanService { PlanServiceMock() }
    func makeSearchStorage() -> SearchStorage { SearchModuleStorage() }
}

struct AnnouncementManagerMock: AnnouncementManager {
    var hasUnreadAnnouncements: Bool { false }
    func fetchCurrentAnnouncementsFromStorage() -> [Announcement] { [] }
    func fetchCurrentOfferBannerFromStorage() -> Announcement? { nil }
    func offerBannerViewModel(dismiss: @escaping (Announcement) -> Void) -> OfferBannerViewModel? { nil }
    func markAsRead(announcement: Announcement) { }
    func shouldShowAnnouncementsIcon() -> Bool { false }
}

struct CountryServiceMock: CountryService {
    func makeCountriesViewController() -> CountriesViewController { CountriesViewController() }
    func makeCountryViewController(country: CountryItemViewModel) -> CountryViewController { CountryViewController() }
}

enum MockServerGroup {

    static var dev: ServerGroupInfo {
        .init(kind: .gateway(name: "Dev"), featureIntersection: .restricted, featureUnion: .restricted, minTier: .paidTier, maxTier: .paidTier, serverCount: 2, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: false, isUnderMaintenance: false, protocolSupport: .wireGuardUDP)
    }

    static var sweden: ServerGroupInfo {
        .init(kind: .country(code: "SE"), featureIntersection: .zero, featureUnion: .zero, minTier: .paidTier, maxTier: .paidTier, serverCount: 3, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: true, isUnderMaintenance: false, protocolSupport: .all)
    }

    static var switzerland: ServerGroupInfo {
        .init(kind: .country(code: "CH"), featureIntersection: .zero, featureUnion: .zero, minTier: .paidTier, maxTier: .paidTier, serverCount: 3, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: true, isUnderMaintenance: false, protocolSupport: .ikev2)
    }

}
