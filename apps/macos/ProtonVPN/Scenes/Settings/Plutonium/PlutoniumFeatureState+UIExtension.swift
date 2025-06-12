//
//  Created on 2025-05-12 by Pawel Jurczyk.
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

import VPNAppCore

extension PlutoniumFeature.State {
    var remainingApps: [PlutoniumApp] {
        discoveredApps.filter {
            !activatedApps.contains($0)
        }
    }

    var activatedApps: [PlutoniumApp] {
        guard case .enabled(let mode) = feature else { return [] }
        switch mode {
        case .inclusion:
            return inclusionActivated.apps
        case .exclusion:
            return exclusionActivated.apps
        }
    }

    var activatedIPs: [String] {
        guard case .enabled(let mode) = feature else { return [] }
        switch mode {
        case .inclusion:
            return inclusionActivated.ips
        case .exclusion:
            return exclusionActivated.ips
        }
    }
}
