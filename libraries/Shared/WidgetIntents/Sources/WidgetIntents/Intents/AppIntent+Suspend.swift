//
//  Created on 02/06/2026 by Max Kupetskyi.
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

import AppIntents
import UIKit

package extension AppIntent {
    /// Returns the host app to the background after a widget-initiated action completes.
    ///
    /// The suspend action should happen when the app is actually active
    /// Suspending before triggers a crash `__uikit_did_not_receive_a_remote_cacontext_from_coreanimation_`
    /// If the app never becomes active within the timeout we skip the suspension
    func suspendAppIfSupported() async {
        guard await waitUntilActive(timeout: .seconds(5)) else {
            log.info("App did not become active in time; skipping suspension to avoid launch watchdog crash", category: .app)
            return
        }

        try? await Task.sleep(for: .milliseconds(500))

        await MainActor.run {
            let app = UIApplication.shared
            guard app.applicationState == .active else {
                log.info("App is no longer active; skipping app suspension", category: .app)
                return
            }
            let suspendSelector = #selector(URLSessionTask.suspend)
            guard app.responds(to: suspendSelector) else {
                log.error("UIApplication does not respond to suspend selector; skipping app suspension", category: .app)
                return
            }
            _ = app.perform(suspendSelector)
        }
    }

    private func waitUntilActive(timeout: Duration) async -> Bool {
        let pollInterval: Duration = .milliseconds(100)
        var waited: Duration = .zero
        while waited < timeout {
            let isActive = await MainActor.run { UIApplication.shared.applicationState == .active }
            if isActive {
                return true
            }
            try? await Task.sleep(for: pollInterval)
            waited += pollInterval
        }
        return await MainActor.run { UIApplication.shared.applicationState == .active }
    }
}
