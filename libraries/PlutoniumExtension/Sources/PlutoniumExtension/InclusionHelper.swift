//
//  Created on 19/05/2025 by Shahin Katebi.
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

import ComposableArchitecture

import Foundation
@preconcurrency import VPNAppCore

struct PlutoniumInclusionHelper {
    private let appIDs: Set<String>
    private let pluginIDs: Set<String>
    private let ipSet: Set<String>
    private let shouldInclude: Bool

    init() throws {
        @SharedReader(.plutoniumFeature) var feature: PlutoniumFeatureToggle

        guard case let .enabled(mode) = feature else {
            log.warning("Plutonium disabled. Should not reach here.")
            throw PlutoniumError.featureDisabled
        }
        switch mode {
        case .exclusion:
            @SharedReader(.exclusionActivated) var exclusionActivated: PlutoniumActivated

            self.appIDs = Set(exclusionActivated.apps.map(\.bundleIdentifier))
            let plugins = exclusionActivated.apps.flatMap(\.plugins)
            self.pluginIDs = Set(plugins.map(\.bundleIdentifier))
            self.ipSet = Set(exclusionActivated.ips)
            self.shouldInclude = false
        case .inclusion:
            @SharedReader(.inclusionActivated) var inclusionActivated: PlutoniumActivated

            self.appIDs = Set(inclusionActivated.apps.map(\.bundleIdentifier))
            let plugins = inclusionActivated.apps.flatMap(\.plugins)
            self.pluginIDs = Set(plugins.map(\.bundleIdentifier))
            self.ipSet = Set(inclusionActivated.ips)
            self.shouldInclude = true
        }
    }

    func appIncluded(withIdentifier identifier: String) -> Bool {
        let found = appIDs.contains(identifier) || pluginIDs.contains(identifier)
        return shouldInclude ? found : !found
    }

    func ipIncluded(_ ip: String) -> Bool {
        let found = ipSet.contains(ip)
        return shouldInclude ? found : !found
    }
}
