//
//  Created on 24/03/2023.
//
//  Copyright (c) 2023 Proton AG
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

import Foundation

public struct NetShieldStatsViewModel {
    public struct NetShieldStat {
        let value: String
        let title: String
        let help: String
        let isDisabled: Bool

        public init(value: String, title: String, help: String, isDisabled: Bool) {
            self.value = value
            self.title = title
            self.help = help
            self.isDisabled = isDisabled
        }
    }

    let adsStats: NetShieldStat
    let trackersStats: NetShieldStat
    let dataStats: NetShieldStat

    public init(adsStats: NetShieldStat,
                trackersStats: NetShieldStat,
                dataStats: NetShieldStat) {
        self.adsStats = adsStats
        self.trackersStats = trackersStats
        self.dataStats = dataStats
    }
}
