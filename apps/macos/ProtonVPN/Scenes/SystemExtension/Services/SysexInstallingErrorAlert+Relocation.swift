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
import Domain

import Telemetry
import VPNAppCore

extension RelocationPromptAlert {
    /// Creates the prompt for where the app runs from and reports it to telemetry, or returns nil when the app is in
    /// `/Applications`.
    static func reporting(
        entryPoint: SystemExtensionEvent.EntryPoint,
        location: BundleLocation = .current
    ) -> RelocationPromptAlert? {
        @Dependency(\.telemetryService) var telemetryService
        let report = { (report: SystemExtensionEvent.Report) in
            Task {
                // The scheduler throws when the user has not opted in to usage data, which is expected.
                try? await telemetryService.systemExtensionEvent(report)
            }
        }

        let alert = RelocationPromptAlert(
            location: location,
            showInFinder: {
                NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                report(.relocationPromptAction(.openedFinder))
            },
            dismissed: {
                report(.relocationPromptAction(.dismissed))
            }
        )
        if alert != nil {
            report(.relocationPromptDisplay(entryPoint: entryPoint))
        }
        return alert
    }
}

extension SysexInstallingErrorAlert {
    /// Creates the alert for a failed activation. An app outside `/Applications` gets the relocation prompt instead.
    static func reportingRelocation(
        error: Error,
        entryPoint: SystemExtensionEvent.EntryPoint,
        location: BundleLocation = .current
    ) -> SystemAlert? {
        guard let alert = SysexInstallingErrorAlert(error: error) else {
            return nil
        }
        guard alert.isBadInstallLocation else {
            return alert
        }
        return RelocationPromptAlert.reporting(entryPoint: entryPoint, location: location) ?? alert
    }
}
