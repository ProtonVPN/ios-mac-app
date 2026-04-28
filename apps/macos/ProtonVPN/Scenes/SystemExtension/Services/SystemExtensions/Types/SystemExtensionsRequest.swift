//
//  Created on 28/04/2026 by Max Kupetskyi.
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

enum SystemExtensionsRequestOrigin: String, Equatable {
    case appStartup
    case login
    case connectionSettings
    case protocolSwitch
    case profileConnection
    case profileEditing
    case plutonium
    case termination
    case clearData
}

enum SystemExtensionsRequestKind: Equatable {
    case installOrUpdate(shouldStartTour: Bool, includedTypes: [SystemExtensionType])
    case checkAndInstallOrUpdate(shouldStartTour: Bool, includedTypes: [SystemExtensionType])
    case uninstallAll(userInitiated: Bool, timeout: DispatchTime?)
}

struct SystemExtensionsRequest: Equatable {
    let id: UUID
    let origin: SystemExtensionsRequestOrigin
    let kind: SystemExtensionsRequestKind

    init(
        id: UUID = UUID(),
        origin: SystemExtensionsRequestOrigin,
        kind: SystemExtensionsRequestKind
    ) {
        self.id = id
        self.origin = origin
        self.kind = kind
    }
}
