//
//  Created on 25/06/2026 by Max Kupetskyi.
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

import Combine
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct UpdateManager {
    /// Whether the updater is currently relaunching the app to apply an update
    ///
    /// `true` only while Sparkle is relaunching on macOS — used to skip the quit confirmation prompt
    /// Always `false` on iOS
    public var isRelaunchingForUpdate: () -> Bool = { false }

    /// Whether a newer app version is available.
    public var isUpdateAvailable: () async -> Bool = { false }

    /// The minimum OS version required by the next available update.
    public var minimumVersionRequiredByNextUpdate: () async -> OperatingSystemVersion = {
        ProcessInfo.processInfo.operatingSystemVersion
    }

    /// Begin the update flow (Sparkle on macOS, opens the App Store listing on iOS)
    public var startUpdate: () -> Void

    /// Trigger an update check. macOS/Sparkle only; no-op on iOS
    public var checkForUpdates: (_ userInitiated: Bool) -> Void = { _ in }

    /// Release date of the running version, taken from the appcast. macOS only; `nil` on iOS
    public var currentVersionReleaseDate: () -> Date? = { nil }

    /// Release notes for the available updates, taken from the appcast. macOS only; `nil` on iOS
    public var releaseNotes: () -> [String]? = { nil }

    /// Emits whenever update state changes — e.g. Sparkle finishes loading the appcast — so observers
    /// can refresh displayed update info (release notes, release date). macOS only
    public var stateUpdates: () -> AnyPublisher<Void, Never> = { Empty().eraseToAnyPublisher() }
}

extension UpdateManager: TestDependencyKey {
    public static let testValue = UpdateManager()
}

public extension DependencyValues {
    var updateManager: UpdateManager {
        get { self[UpdateManager.self] }
        set { self[UpdateManager.self] = newValue }
    }
}
