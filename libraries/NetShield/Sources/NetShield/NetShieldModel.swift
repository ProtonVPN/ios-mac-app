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

public final class NetShieldModel: Sendable, Equatable, ObservableObject {
    public let trackersCount: Int
    public let adsCount: Int
    public let dataSaved: UInt64
    public let enabled: Bool

    public static func == (lhs: NetShieldModel, rhs: NetShieldModel) -> Bool {
        lhs.ads == rhs.ads &&
        lhs.trackers == rhs.trackers &&
        lhs.data == rhs.data &&
        lhs.enabled == rhs.enabled
    }

    public init(trackersCount: Int, adsCount: Int, dataSaved: UInt64, enabled: Bool) {
        self.trackersCount = trackersCount
        self.adsCount = adsCount
        self.dataSaved = dataSaved
        self.enabled = enabled
    }

    public static func zero(enabled: Bool) -> NetShieldModel {
        .init(trackersCount: 0, adsCount: 0, dataSaved: 0, enabled: false)
    }

    public func copy(enabled: Bool) -> NetShieldModel {
        .init(trackersCount: trackersCount, adsCount: adsCount, dataSaved: dataSaved, enabled: enabled)
    }
}

public struct StatModel: Equatable {
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

extension NetShieldModel {

    private static let formatter = NetShieldStatsNumberFormatter()
    private static let byteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    public var trackers: StatModel {
        StatModel(
            value: Self.formatter.string(from: trackersCount),
            title: Localizable.netshieldStatsTrackersStopped(trackersCount),
            help: Localizable.netshieldStatsHintTrackers,
            isEnabled: enabled
        )
    }

    public var ads: StatModel {
        StatModel(
            value: Self.formatter.string(from: adsCount),
            title: Localizable.netshieldStatsAdsBlocked(adsCount),
            help: Localizable.netshieldStatsHintAds,
            isEnabled: enabled
        )
    }

    public var data: StatModel {
        StatModel(
            value: Self.byteCountFormatter.string(fromByteCount: Int64(dataSaved)),
            title: Localizable.netshieldStatsDataSaved,
            help: Localizable.netshieldStatsHintData,
            isEnabled: enabled
        )
    }
}

public extension NetShieldModel {
    static var random: NetShieldModel { // TODO: make only available in DEBUG for previews
        let trackers = Int.random(in: 0...1000)
        let ads = Int.random(in: 0...1000000000)
        let data = UInt64.random(in: 0...100000000000000)
        return NetShieldModel(trackersCount: trackers, adsCount: ads, dataSaved: data, enabled: true)
    }
}
