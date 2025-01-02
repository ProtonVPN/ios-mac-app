//
//  Created on 07/06/2024.
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

#if compiler(>=6) && canImport(Testing)

import OrderedCollections
import Testing
import SnapshotTesting
import ComposableArchitecture
import VPNAppCore
import Domain
import Ergonomics
@testable import Home
@testable import Home_iOS
import SwiftUI

extension Locale {
    static let en = Locale(identifier: "en")
}

@Suite("Home")
struct SwiftTestingTests {

    @available(iOS 17, *)
    @Test("Home screen")
    @MainActor
    func homeScreen() async throws {

        let store = Store(initialState: HomeFeature.State(), reducer: HomeFeature.init) {
            $0.serverChangeAuthorizer = .availableValue
            $0.locale = .en
            $0.date = .constant(Date())
        }
        let appView = HomeView(store: store)
            .frame(.rect(width: 375, height: 667)) // iphone se 2022 size
            .transaction { $0.animation = nil }
            .environment(\._accessibilityReduceMotion, true)

        withDependencies {
            $0.locale = .en
            $0.date = .constant(Date())
        } operation: {
            @Shared(.protectionState) var protectionState: ProtectionState
            @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus
            @Shared(.userTier) var userTier: Int
            @Shared(.userCountry) var userCountry: String?
            @Shared(.userIP) var userIP: String?
            @Shared(.recents) var recents: OrderedSet<RecentConnection>
            $recents |=| [.connectionRegion, .connectionSecureCoreFastest, .connectionSecureCore]
            store.send(.map(.observeConnectionState))

            $userCountry |=| "PL"
            $userIP |=| "1.2.3.4"

            $userTier |=| .freeTier
            $protectionState |=| .unprotected
            $vpnConnectionStatus |=| .disconnected

            assertSnapshot(of: appView,
                           as: .image(traits: UITraitCollection(userInterfaceStyle: .dark)),
                           testName: "1.1 Home Free Unprotected")
            let actual = VPNConnectionActual.mock(country: "PL",
                                                  coordinates: .init(latitude: 52.229686, longitude: 21.012247))

            $protectionState |=| .protecting(country: "Poland", ip: "1.2.3.4")
            $vpnConnectionStatus |=| .connecting(.specificCountryServer, actual)

            assertSnapshot(of: appView,
                           as: .image(traits: UITraitCollection(userInterfaceStyle: .dark)),
                           testName: "1.2 Home Free Protecting")

            $protectionState |=| .protected(netShield: .zero(enabled: false))
            $vpnConnectionStatus |=| .connected(.specificCountryServer, actual)

            assertSnapshot(of: appView,
                           as: .image(traits: UITraitCollection(userInterfaceStyle: .dark)),
                           testName: "1.3 Home Free Protected")

            $userTier |=| .paidTier
            $protectionState |=| .unprotected
            $vpnConnectionStatus |=| .disconnected

            assertSnapshot(of: appView,
                           as: .image(traits: UITraitCollection(userInterfaceStyle: .dark)),
                           testName: "2.1 Home Paid Unprotected")

            $protectionState |=| .protecting(country: "Poland", ip: "1.2.3.4")
            $vpnConnectionStatus |=| .connecting(.specificCountryServer, actual)

            assertSnapshot(of: appView,
                           as: .image(traits: UITraitCollection(userInterfaceStyle: .dark)),
                           testName: "2.2 Home Paid Protecting")

            $protectionState |=| .protected(netShield: .init(trackersCount: 432, adsCount: 12345, dataSaved: 123_456_789, enabled: true))
            $vpnConnectionStatus |=| .connected(.specificCountryServer, actual)

            assertSnapshot(of: appView,
                           as: .image(traits: UITraitCollection(userInterfaceStyle: .dark)),
                           testName: "2.3 Home Paid Protected")
        }
    }
}

infix operator |=|

public func |=| <Value> (lhs: Shared<Value>, rhs: Value) {
    lhs.withLock { $0 = rhs }
}

#endif

/*
 We should only have a few tests on the whole home page, it's not meant to be comprehensive, just to make sure the elements fit together
 Home screen: both dark and light (12), all centered on a different country
 - free user; unprotected; ; upsells
 - free user; unprotected; upsells visible first
 - free user; protected; upsells visible last
 - paid user; protected; with recents
 - paid user; unprotected; with recents scrolled to bottom

 Map: only the map with pin, without the other elements, every using different country, both dark and light (12)
 - whole map without pin, without country
 - country with pin unprotected
 - country with pin protecting
 - country with pin protected
 - biggest country with pin protected
 - smallest country with pin protected

 Connection status: both dark and light (12)
 - unprotected, without location info
 - unprotected, with location info
 - protected free user with netshield banner
 - protected free user with change server banner
 - protected paid user with netshield
 - protected paid user without netshield

 Connection card: (16) both dark and light
 - free user, fastest country disconnected
 - free user, fastest country connected
 - paid user, fastest country secure core
 - paid user, specific country, connected
 - paid user, specific country, disconnected, secure core
 - paid user, specific country and city disconnected
 - paid user, specific country, city and server connected
 - paid user, specific country and server disconnected

 Recents:
 - under maintenance
 - secure core
 - more

 */
