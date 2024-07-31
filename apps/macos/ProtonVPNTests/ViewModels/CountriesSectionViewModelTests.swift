//
//  Created on 12/02/2024.
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

    var serverGroups: [ServerGroupInfo]!

    func withMockedRepository<T>(_ operation: () -> T) -> T {
        return withDependencies {
            // Normally we would be able to omit all arguments except groups, but doing so triggers a linker bug with XCTDynamicOverlay.
            $0.serverRepository = .init(
                serverCount: { 0 },
                upsertServers: { _ in },
                server: { _, _ in nil },
                servers: { _, _ in [] },
                deleteServers: { _, _ in 0 },
                upsertLoads: { _ in },
                groups: { _, _ in self.serverGroups },
                getMetadata: { _ in nil },
                setMetadata: { _, _ in }
            )
        } operation: {
            operation()
        }
    }

    func makeViewModel() -> CountriesSectionViewModel {
        withMockedRepository {
            CountriesSectionViewModel(factory: mockFactory)
        }
    }

    func testConnectionProtocolChangedUpdatesCountryItems() {
        // Start off with smart protocol enabled and all protocols supported
        mockPropertiesManager.secureCoreToggle = false
        mockPropertiesManager.connectionProtocol = .smartProtocol
        serverGroups = [MockServerGroup.dev, MockServerGroup.sweden, MockServerGroup.switzerland]

        let sut = makeViewModel()

        // All server groups provide at least one supported protocol
        assert(sut.cellModel(forRow: 0)!, isHeaderWithTitle: "Gateways")
        assert(sut.cellModel(forRow: 1)!, isServerGroupOfKind: .gateway(name: "Dev"), isUnderMaintenance: false)

        assert(sut.cellModel(forRow: 2)!, isHeaderWithTitle: "All locations (2)")
        assert(sut.cellModel(forRow: 3)!, isServerGroupOfKind: .country(code: "SE"), isUnderMaintenance: false)
        assert(sut.cellModel(forRow: 4)!, isServerGroupOfKind: .country(code: "CH"), isUnderMaintenance: false)

        // Now let's update our protocol to WireGuard UDP
        mockPropertiesManager.connectionProtocol = .vpnProtocol(.wireGuard(.udp))
        withMockedRepository {
            NotificationCenter.default.post(name: PropertiesManager.vpnProtocolNotification, object: nil)
        }

        // Switzerland should now be placed under maintenance (it's only supports ike)
        assert(sut.cellModel(forRow: 4)!, isServerGroupOfKind: .country(code: "CH"), isUnderMaintenance: true)

        // Finally, let's try changing our protocol to Stealth
        mockPropertiesManager.connectionProtocol = .vpnProtocol(.wireGuard(.tls))
        withMockedRepository {
            NotificationCenter.default.post(name: PropertiesManager.vpnProtocolNotification, object: nil)
        }

        // Dev gateway should now also be under maintenance
        assert(sut.cellModel(forRow: 1)!, isServerGroupOfKind: .gateway(name: "Dev"), isUnderMaintenance: true)
    }

    private func assert(_ cellVM: CellModel, isHeaderWithTitle title: String) {
        guard case .header(let headerVM) = cellVM else {
            XCTFail("Expected row view model to be a server group, but found: \(cellVM)")
            return
        }
        XCTAssertEqual(headerVM.title, title)
    }

    private func assert(_ cellVM: CellModel, isServerGroupOfKind kind: ServerGroupInfo.Kind, isUnderMaintenance: Bool) {
        guard case .country(let groupVM) = cellVM else {
            XCTFail("Expected row view model to be a server group, but found: \(cellVM)")
            return
        }
        XCTAssertEqual(groupVM.groupKind, kind)
        XCTAssertEqual(groupVM.isServerUnderMaintenance, isUnderMaintenance)
    }
}

class DependencyFactory: CountriesSectionViewModel.Factory, ProfileManagerFactory, ProfileStorageFactory {
    let propertiesManager: PropertiesManagerProtocol

    init(propertiesManager: PropertiesManagerMock) {
        self.propertiesManager = propertiesManager
    }

    func makeVpnGateway() -> VpnGatewayProtocol {
        let gateway = VpnGatewayMock(propertiesManager: propertiesManager, activeServerType: .unspecified, connection: .disconnected)
        gateway._userTier = 3
        return gateway
    }

    func makeAnnouncementManager() -> AnnouncementManager { AnnouncementManagerMock() }
    func makeAppStateManager() -> AppStateManager { AppStateManagerMock() }
    func makeCoreAlertService() -> CoreAlertService { CoreAlertServiceDummy() }
    func makeNATTypePropertyProvider() -> NATTypePropertyProvider { NATTypePropertyProviderMock() }
    func makeNetShieldPropertyProvider() -> NetShieldPropertyProvider { NetShieldPropertyProviderMock() }
    func makeProfileManager() -> LegacyCommon.ProfileManager { ProfileManager(self) }
    func makeProfileStorage() -> LegacyCommon.ProfileStorage { ProfileStorage(authKeychain: AuthKeychainHandleMock()) }
    func makeSystemExtensionManager() -> LegacyCommon.SystemExtensionManager { SystemExtensionManagerMock(factory: self) }
    func makeVpnManager() -> LegacyCommon.VpnManagerProtocol { VpnManagerMock() }
    func makeVpnStateConfiguration() -> LegacyCommon.VpnStateConfiguration { fatalError() }
    func makeModelIdChecker() -> ProtonVPN.ModelIdCheckerProtocol { fatalError() }
    func makePropertiesManager() -> PropertiesManagerProtocol { propertiesManager }
    func makeVpnKeychain() -> VpnKeychainProtocol { VpnKeychainMock(maxTier: .paidTier) }
    func makeSessionService() -> SessionService { SessionServiceMock() }
}

struct AnnouncementManagerMock: AnnouncementManager {
    var hasUnreadAnnouncements: Bool { false }
    func fetchCurrentAnnouncementsFromStorage() -> [Announcement] { [] }
    func fetchCurrentOfferBannerFromStorage() -> Announcement? { nil }
    func offerBannerViewModel(dismiss: @escaping (Announcement) -> Void) -> OfferBannerViewModel? { nil }
    func markAsRead(announcement: Announcement) { }
    func shouldShowAnnouncementsIcon() -> Bool { false }
}

enum MockServerGroup {

    static var dev: ServerGroupInfo {
        .init(kind: .gateway(name: "Dev"), featureIntersection: .restricted, featureUnion: .restricted, minTier: .paidTier, maxTier: .paidTier, serverCount: 2, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: false, isUnderMaintenance: false, protocolSupport: .wireGuardUDP)
    }

    static var sweden: ServerGroupInfo {
        .init(kind: .country(code: "SE"), featureIntersection: .zero, featureUnion: .zero, minTier: .paidTier, maxTier: .paidTier, serverCount: 3, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: true, isUnderMaintenance: false, protocolSupport: [.wireGuardTCP, .wireGuardUDP, .wireGuardTLS])
    }

    static var switzerland: ServerGroupInfo {
        .init(kind: .country(code: "CH"), featureIntersection: .zero, featureUnion: .zero, minTier: .paidTier, maxTier: .paidTier, serverCount: 3, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: true, isUnderMaintenance: false, protocolSupport: .ikev2)
    }

}
