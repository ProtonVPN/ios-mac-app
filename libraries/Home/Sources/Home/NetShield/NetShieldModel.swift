//
//  Created on 13/06/2023.
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
import Strings

public class NetShieldModel: Equatable, ObservableObject {
    public static func == (lhs: NetShieldModel, rhs: NetShieldModel) -> Bool {
        lhs.ads == rhs.ads &&
        lhs.trackers == rhs.trackers &&
        lhs.data == rhs.data &&
        lhs.enabled == rhs.enabled
    }

    private static let formatter = NetShieldStatsNumberFormatter()
    private static let byteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    public var trackers: Stat
    public var ads: Stat
    public var data: Stat

    public var trackersCount: Int
    public var adsCount: Int

    public init(trackers: Stat, ads: Stat, data: Stat, trackersCount: Int, adsCount: Int) {
        self.trackers = trackers
        self.ads = ads
        self.data = data
        self.trackersCount = trackersCount
        self.adsCount = adsCount
    }

    public convenience init(trackers: Int, ads: Int, data: Int, enabled: Bool) {
        let adsStat = Stat(value: Self.formatter.string(from: ads),
                           title: Localizable.netshieldStatsAdsBlocked(ads),
                           help: Localizable.netshieldStatsHintAds,
                           isEnabled: enabled)
        let trackersStat = Stat(value: Self.formatter.string(from: trackers),
                                title: Localizable.netshieldStatsTrackersStopped(trackers),
                                help: Localizable.netshieldStatsHintTrackers,
                                isEnabled: enabled)
        let dataStat = Stat(value: Self.byteCountFormatter.string(fromByteCount: Int64(data)),
                            title: Localizable.netshieldStatsDataSaved,
                            help: Localizable.netshieldStatsHintData,
                            isEnabled: enabled)

        self.init(trackers: trackersStat,
                  ads: adsStat,
                  data: dataStat,
                  trackersCount: trackers,
                  adsCount: ads)
    }

    public var enabled: Bool {
        set {
            trackers.isEnabled = newValue
            ads.isEnabled = newValue
            data.isEnabled = newValue
        } get {
            ads.isEnabled
        }
    }

    public struct Stat: Equatable {
        public let value: String
        public let title: String
        public let help: String
        public var isEnabled: Bool

        public init(value: String, title: String, help: String, isEnabled: Bool) {
            self.value = value
            self.title = title
            self.help = help
            self.isEnabled = isEnabled
        }
    }
}

public extension NetShieldModel {
    static var random: NetShieldModel {
        let trackers = Int.random(in: 0...1000)
        let ads = Int.random(in: 0...1000000000)
        let data = Int.random(in: 0...100000000000000)
        return NetShieldModel(trackers: trackers, ads: ads, data: data, enabled: true)
    }
}
