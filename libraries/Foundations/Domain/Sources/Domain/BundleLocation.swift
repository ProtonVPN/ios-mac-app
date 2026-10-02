//
//  Created on 01/10/2026 by Max Kupetskyi.
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

/// Where the running app bundle lives. macOS activates system extensions only for an app in `/Applications`.
public enum BundleLocation: Equatable, Sendable {
    case applications
    case downloads
    /// A mounted volume, usually the disk image the app came in.
    case dmgVolume
    /// A randomized read-only copy that Gatekeeper runs instead of a quarantined app. The app cannot see where the
    /// original is, and the user cannot move the copy.
    case translocated
    case other

    public init(bundlePath: String) {
        let components = URL(fileURLWithPath: bundlePath).pathComponents
        // A translocated copy can sit under any of the folders below, so it is checked first.
        if components.contains("AppTranslocation") {
            self = .translocated
        } else if components.starts(with: ["/", "Applications"]) {
            self = .applications
        } else if components.starts(with: ["/", "Volumes"]) {
            self = .dmgVolume
        } else if components.count > 3, components.starts(with: ["/", "Users"]), components[3] == "Downloads" {
            self = .downloads
        } else {
            self = .other
        }
    }

    /// The location of the running app.
    public static var current: Self {
        Self(bundlePath: Bundle.main.bundlePath)
    }
}
