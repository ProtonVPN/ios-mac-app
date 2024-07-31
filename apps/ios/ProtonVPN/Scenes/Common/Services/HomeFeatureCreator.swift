//
//  Created on 30/07/2024.
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

import UIKit
import Strings
import ProtonCoreUIFoundations
import SwiftUI
import Home
import Home_iOS
import Settings_iOS
import ComposableArchitecture
import NEHelper
import VPNAppCore

@available(iOS 17, *)
enum HomeFeatureCreator {
    static func homeViewController() -> UIHostingController<HomeView> {
        let homeStore = StoreOf<HomeFeature>(initialState: .init()) {
            HomeFeature()
                .dependency(\.vpnConnectionStatusPublisher, VPNConnectionStatusPublisherKey.watchVPNConnectionStatusChanges)
#if targetEnvironment(simulator)
                .dependency(\.connectToVPN, SimulatorHelper.shared.connect)
                .dependency(\.disconnectVPN, SimulatorHelper.shared.disconnect)
#else
                .dependency(\.connectToVPN, ConnectToVPNKey.bridgedConnect)
                .dependency(\.disconnectVPN, DisconnectVPNKey.bridgedDisconnect)
#endif
        }

        let hostingController = UIHostingController(rootView: HomeView(store: homeStore))
        hostingController.tabBarItem = UITabBarItem(title: Localizable.homeTab,
                                                    image: IconProvider.houseFilled,
                                                    tag: 0)
        return hostingController
    }
}
