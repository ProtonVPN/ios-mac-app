//
//  Created on 01/12/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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

import Dependencies
import Foundation
import ios_app
import Settings
import SwiftUI
import UIKit

// MARK: - Live Implementation

extension WelcomeFlowPresenter: @retroactive DependencyKey {
    public static let liveValue = WelcomeFlowPresenter { initialError, overlayViewController, showWelcome in
        #if DEBUG || STAGING
            // In debug/staging builds, show the environment selector first
            handleDebugStubs()
            showDebugConfiguration(
                initialError: initialError,
                overlayViewController: overlayViewController,
                showWelcome: showWelcome
            )
        #else
            // In production, go straight to welcome screen
            showWelcome(initialError, overlayViewController)
        #endif
    }
}

// MARK: - Private Helpers

#if DEBUG || STAGING
    private func showDebugConfiguration(
        initialError: String?,
        overlayViewController: UIViewController?,
        showWelcome: @escaping (String?, UIViewController?) -> Void
    ) {
        // Check for debug stubs first
        handleDebugStubs()

        @Dependency(\.windowService) var windowService

        let appDebugConfigurationView = EnvironmentSelectorMobileView(continueHandler: {
            // When user continues from debug config, show the actual welcome screen
            showWelcome(initialError, overlayViewController)
        })

        let environmentsViewController = UIHostingController(rootView: appDebugConfigurationView)
        windowService.show(viewController: environmentsViewController)
    }
#endif

private func handleDebugStubs() {
    #if DEBUG || STAGING
        if ProcessInfo.processInfo.environment["ExtAccountNotSupportedStub"] != nil {
            LoginExternalAccountNotSupportedSetup.start()
        }
    #endif
}
