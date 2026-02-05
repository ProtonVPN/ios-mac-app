//
//  Created on 2026-02-05 by Pawel Jurczyk.
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

#if DEBUG
    import Dependencies
    import Settings
    import SwiftUI

    extension UIWindow {
        override open func motionEnded(_ motion: UIEvent.EventSubtype, with _: UIEvent?) {
            guard motion == .motionShake else { return }
            @Dependency(\.windowService) var windowService

            let appDebugConfigurationView = EnvironmentSelectorMobileView(continueHandler: {})

            let environmentsViewController = UIHostingController(rootView: appDebugConfigurationView)
            windowService.present(modal: environmentsViewController)
        }
    }
#endif
