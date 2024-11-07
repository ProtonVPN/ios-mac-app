//
//  Created on 05.04.24.
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

import SwiftUI
import Dependencies
import PMLogger
import ProtonCoreLog
import VPNAppCore
import VPNShared
import Domain
import CommonNetworking
import ProtonCoreFeatureFlags

import tvOS

@main
struct ProtonVPNApp: App {
    var body: some Scene {
        WindowGroup {
            AppView()
                .onAppear { self.startup() }
        }
    }
}

extension ProtonVPNApp {
    private func startup() {
        // Clear out any overrides that may have been present in previous builds
        FeatureFlagsRepository.shared.resetOverrides()

        SentryHelper.setupSentry(
            dsn: ObfuscatedConstants.sentryDsntvOS,
            isEnabled: {
                FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.sentry)
            },
            getUserId: {
                @Dependency(\.authKeychain) var authKeychain

                return authKeychain.userId
            }
        )
    }
}
