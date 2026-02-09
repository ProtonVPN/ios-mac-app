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

import CommonNetworking
import Dependencies
import Domain
import Ergonomics
import Logging
import PMLogger
import ProtonCoreFeatureFlags
import ProtonCoreLog
import SwiftUI
import VPNAppCore
import VPNShared

#if DEBUG
    import Atlantis
#endif

@main
struct ProtonVPNApp: App {
    init() {
        setupLogsForApp()
        #if DEBUG
            Atlantis.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .task { await startup() }
        }
    }
}

extension ProtonVPNApp {
    @MainActor
    private func startup() async {
        // Clear out any overrides that may have been present in previous builds
        FeatureFlagsRepository.shared.resetOverrides()

        do {
            @Dependency(\.migrationManager) var migrationManager
            try await migrationManager.migrate()
        } catch {
            PMLog.error("Migration failed: \(error)")
        }

        @Dependency(\.networking) var networking
        do {
            let session = try await networking.apiService.acquireSessionIfNeeded().get()
            switch session {
            case let .sessionAlreadyPresent(authCredential), let .sessionFetchedAndAvailable(authCredential):
                FeatureFlagsRepository.shared.setApiService(networking.apiService)
                if !authCredential.userID.isEmpty {
                    FeatureFlagsRepository.shared.setUserId(authCredential.userID)
                }

                await CheckedFeatureFlagsRepository.shared.fetchFlags()
            default:
                break
            }
        } catch {
            PMLog.error("acquireSessionIfNeeded didn't succeed and therefore flags didn't get fetched: \(error)")
        }

        SentryHelper.setupSentry(
            dsn: ObfuscatedConstants.sentryDsntvOS,
            isEnabled: { true },
            getUserId: {
                @Dependency(\.authKeychain) var authKeychain
                return authKeychain.userId
            }
        )
    }
}

extension ProtonVPNApp {
    private func setupLogsForApp() {
        @Dependency(\.logFileManager) var logFileManager
        let logFile = logFileManager.getFileUrl(named: appLogFilename)

        let fileLogHandler = FileLogHandler(logFile)
        let osLogHandler = OSLogHandler(formatter: OSLogFormatter())
        let multiplexLogHandler = MultiplexLogHandler([osLogHandler, fileLogHandler])

        LoggingSystem.bootstrap { _ in multiplexLogHandler }
        log = Logging.Logger(label: "ProtonVPN.tvOS.logger")
    }
}

package let appLogFilename = "ProtonVPN.log"
