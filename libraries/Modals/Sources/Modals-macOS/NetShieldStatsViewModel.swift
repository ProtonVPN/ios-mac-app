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
import Modals

public class NetShieldStatsViewModel: ObservableObject {
    public struct NetShieldStat {
        var value: String
        let title: String
        let help: String
        var isDisabled: Bool

        public init(value: String, title: String, help: String, isDisabled: Bool) {
            self.value = value
            self.title = title
            self.help = help
            self.isDisabled = isDisabled
        }
    }

    var adsStats: NetShieldStat
    var trackersStats: NetShieldStat
    var dataStats: NetShieldStat

    public init(adsStats: NetShieldStat, trackersStats: NetShieldStat, dataStats: NetShieldStat) {
        self.adsStats = adsStats
        self.trackersStats = trackersStats
        self.dataStats = dataStats
    }

    public init(adsStatsTitle: String, trackersStatsTitle: String, dataStatsTitle: String) {
        self.adsStats = .init(value: "",
                              title: adsStatsTitle,
                              help: LocalizedString.netshieldStatsHintAds,
                              isDisabled: true)
        self.trackersStats = .init(value: "",
                                   title: trackersStatsTitle,
                                   help: LocalizedString.netshieldStatsHintTrackers,
                                   isDisabled: true)
        self.dataStats = .init(value: "",
                               title: dataStatsTitle,
                               help: LocalizedString.netshieldStatsHintData,
                               isDisabled: true)
    }

    public func update(adsStats: (value: String, enabled: Bool),
                       trackersStats: (value: String, enabled: Bool),
                       dataStats: (value: String, enabled: Bool)) {
        self.adsStats.value = adsStats.value
        self.trackersStats.value = trackersStats.value
        self.dataStats.value = dataStats.value
        setEnabled(adsStats: adsStats.enabled, trackersStats: trackersStats.enabled, dataStats: dataStats.enabled)
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    private func setEnabled(adsStats: Bool, trackersStats: Bool, dataStats: Bool) {
        self.adsStats.isDisabled = !adsStats
        self.trackersStats.isDisabled = !trackersStats
        self.dataStats.isDisabled = !dataStats
    }
}
