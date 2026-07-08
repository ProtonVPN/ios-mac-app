//
//  Created on 2022-07-13.
//
//  Copyright (c) 2022 Proton AG
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

#if DEBUG
    import CommonNetworking
    import CommonNetworkingTestSupport
    import Dependencies
    import Domain
    import Foundation
    import Localization
    import NetworkExtension
    import Timer
    import TimerMock
    import VPNShared
    import VPNSharedTesting

    open class MockDependencyContainer {
        @Dependency(\.serverRepository) var serverRepository

        public static let appGroup = "test"

        lazy var appSessionRefresher = withDependencies {
            $0.serverRepository = self.serverRepository
        } operation: {
            AppSessionRefresherMock()
        }

        lazy var appSessionRefreshTimer = AppSessionRefreshTimerImplementation(
            factory: MockFactory(container: self),
            refreshIntervals: (30, 30, 30, 30, 30),
            delegate: self
        )

        public lazy var clock = TestClock()
        public lazy var vpnKeychain = VpnKeychainMock()
        public lazy var dohVpn = DoHVPN.mock

        public init() {}
    }

    extension MockDependencyContainer: AppSessionRefreshTimerDelegate {}

    /// This exists so that MockDependencyContainer won't create reference cycles by passing `self` as an
    /// argument to dependency initializers.
    class MockFactory {
        unowned var container: MockDependencyContainer

        init(container: MockDependencyContainer) {
            self.container = container
        }
    }

    extension MockFactory: AppSessionRefresherFactory {
        func makeAppSessionRefresher() -> AppSessionRefresher {
            container.appSessionRefresher
        }
    }
#endif
