//
//  Created on 29/09/2026 by Max Kupetskyi.
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

import AppKit
import Foundation

import Dependencies

import Telemetry
import VPNAppCore

extension SysexInstallingErrorAlert {
    /// Creates the alert for a failed activation, and reports it when it is the install location recovery prompt.
    ///
    /// When the app runs from outside `/Applications`, the alert offers to show the app in Finder, so the user can
    /// move it there. Telemetry then records that the prompt was shown and which button the user pressed.
    static func reportingRelocation(
        error: Error,
        entryPoint: SystemExtensionEvent.EntryPoint
    ) -> SysexInstallingErrorAlert? {
        @Dependency(\.telemetryService) var telemetryService
        let report = { (report: SystemExtensionEvent.Report) in
            Task {
                // The scheduler throws when the user has not opted in to usage data, which is expected.
                try? await telemetryService.systemExtensionEvent(report)
            }
        }

        let relocation = RelocationHandlers(
            showInFinder: {
                NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                report(.relocationPromptAction(.openedFinder))
            },
            dismissed: {
                report(.relocationPromptAction(.dismissed))
            }
        )
        guard let alert = SysexInstallingErrorAlert(error: error, relocation: relocation) else {
            return nil
        }
        if alert.isBadInstallLocation {
            report(.relocationPromptDisplay(entryPoint: entryPoint))
        }
        return alert
    }
}
