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

// TODO: VPNAPPL-2541, Should be a struct instead of a class (and remove ObservableObject conformance as well)
public final class NetShieldModel: Sendable, Equatable, ObservableObject {
    public let trackersCount: Int
    public let adsCount: Int
    public let dataSaved: UInt64
    public let enabled: Bool

    // TODO: With VPNAPPL-2541, remove this below since we'll get it for free
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

extension NetShieldModel: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "NetShieldModel(trackersCount: \(trackersCount), adsCount: \(adsCount), dataSaved: \(dataSaved), enabled: \(enabled))"
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

    package static let emptyAds: StatModel = .ads(value: "–", count: 0, isEnabled: true)
    package static let emptyTrackers: StatModel = .trackers(value: "–", count: 0, isEnabled: true)
    package static let emptyData: StatModel = .data(value: "–", isEnabled: true)
}

extension NetShieldModel {
    private static let formatter = NetShieldStatsNumberFormatter()
    private static let byteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    public var ads: StatModel {
        .ads(value: Self.formatter.string(from: adsCount), count: adsCount, isEnabled: enabled)
    }

    public var trackers: StatModel {
        .trackers(value: Self.formatter.string(from: trackersCount), count: trackersCount, isEnabled: enabled)
    }

    public var data: StatModel {
        .data(value: Self.byteCountFormatter.string(fromByteCount: Int64(dataSaved)), isEnabled: enabled)
    }
}

extension StatModel {
    public static func trackers(value: String, count: Int, isEnabled: Bool) -> StatModel {
        StatModel(
            value: value,
            title: Localizable.netshieldStatsTrackersStopped(count).replacingOccurrences(of: "\n", with: " "),
            help: Localizable.netshieldStatsHintTrackers,
            isEnabled: isEnabled
        )
    }

    public static func ads(value: String, count: Int, isEnabled: Bool) -> StatModel {
        StatModel(
            value: value,
            title: Localizable.netshieldStatsAdsBlocked(count).replacingOccurrences(of: "\n", with: " "),
            help: Localizable.netshieldStatsHintAds,
            isEnabled: isEnabled
        )
    }

    public static func data(value: String, isEnabled: Bool) -> StatModel {
        StatModel(
            value: value,
            title: Localizable.netshieldStatsDataSaved.replacingOccurrences(of: "\n", with: " "),
            help: Localizable.netshieldStatsHintData,
            isEnabled: isEnabled
        )
    }
}

public extension NetShieldModel {
    static var random: NetShieldModel { // TODO: make only available in DEBUG for previews
        let trackers = Int.random(in: 0...1000)
        let ads = Int.random(in: 0...1_000_000_000)
        let data = UInt64.random(in: 0...100_000_000_000_000)
        return NetShieldModel(trackersCount: trackers, adsCount: ads, dataSaved: data, enabled: true)
    }
}
