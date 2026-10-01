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

import Foundation

import Sharing

/// Turns what features report about system extensions into `SystemExtensionEvent`s.
///
/// It adds the user tier and the install location to every event. It also remembers where the app ran from when the
/// install location recovery prompt was shown. When an activation later succeeds from `/Applications`, it reports
/// the prompt as resolved.
public final class TelemetrySystemExtensionReporter {
    /// The install location when the recovery prompt was shown, kept until an activation succeeds from
    /// `/Applications`. The user usually fixes the location by moving the app and launching it again, so this is
    /// stored rather than kept in memory.
    @Shared(.appStorage("SystemExtensionRelocationPromptLocation")) private var promptedInstallLocation: String?

    private let send: (SystemExtensionEvent) async throws -> Void
    private let userTier: () -> CommonTelemetryDimensions.UserTier
    private let installLocation: () -> SystemExtensionEvent.InstallLocation

    public convenience init(telemetryEventScheduler: TelemetryEventScheduler) {
        self.init(
            send: { try await telemetryEventScheduler.report(event: $0) },
            userTier: { CommonTelemetryDimensions.userTier() },
            installLocation: { SystemExtensionEvent.InstallLocation(.current) }
        )
    }

    init(
        send: @escaping (SystemExtensionEvent) async throws -> Void,
        userTier: @escaping () -> CommonTelemetryDimensions.UserTier,
        installLocation: @escaping () -> SystemExtensionEvent.InstallLocation
    ) {
        self.send = send
        self.userTier = userTier
        self.installLocation = installLocation
    }

    public func report(_ report: SystemExtensionEvent.Report) async throws {
        let context = SystemExtensionEvent.Context(installLocation: installLocation(), userTier: userTier())

        // From /Applications there is no location to fix, so there is nothing to see resolved later.
        if case .relocationPromptDisplay = report, context.installLocation != .applications {
            $promptedInstallLocation.withLock { $0 = context.installLocation.rawValue }
        }

        try await send(SystemExtensionEvent(report, context: context))

        if case let .installResult(_, _, outcome, _, _) = report,
           outcome.extensionIsInstalled,
           context.installLocation == .applications {
            try await reportPromptResolved(userTier: context.userTier)
        }
    }

    /// Reports the recovery prompt as resolved, with the location the app ran from when the prompt was shown.
    private func reportPromptResolved(userTier: CommonTelemetryDimensions.UserTier) async throws {
        guard let promptedInstallLocation,
              let location = SystemExtensionEvent.InstallLocation(rawValue: promptedInstallLocation) else {
            return
        }
        $promptedInstallLocation.withLock { $0 = nil }
        let context = SystemExtensionEvent.Context(installLocation: location, userTier: userTier)
        try await send(SystemExtensionEvent(.relocationPromptAction(.resolved), context: context))
    }
}
