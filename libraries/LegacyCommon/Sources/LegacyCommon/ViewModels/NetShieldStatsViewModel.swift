//
//  Created on 22/03/2023.
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

public enum NetShieldStatsViewModel {

//    static let formatter = NetShieldStatsNumberFormatter()
    static let byteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    case disabled
    case enabled(adsBlocked: Int, trackersStopped: Int, bytesSaved: Int, paused: Bool)

    public var adsModel: NetShieldStatsItemModel {
        guard case .enabled(let adsBlocked, _, _, let paused) = self else {
            return .disabled(title: LocalizedString.netshieldStatsAdsBlocked(0))
        }
        let title: String = LocalizedString.netshieldStatsAdsBlocked(adsBlocked)
//        let value = Self.formatter.string(from: adsBlocked)
        return NetShieldStatsItemModel(title: title, value: "value", isEnabled: !paused)
    }

    public var trackersModel: NetShieldStatsItemModel {
        guard case .enabled(_, let trackersStopped, _, let paused) = self else {
            return .disabled(title: LocalizedString.netshieldStatsTrackersStopped(0))
        }
        let title: String = LocalizedString.netshieldStatsTrackersStopped(trackersStopped)
//        let value = Self.formatter.string(from: trackersStopped)
        return NetShieldStatsItemModel(title: title, value: "value", isEnabled: !paused)
    }

    public var dataModel: NetShieldStatsItemModel {
        let title: String = LocalizedString.netshieldStatsDataSaved

        guard case .enabled(_, _, let dataSaved, let paused) = self else {
            return .disabled(title: title)
        }

        let value = Self.byteCountFormatter.string(fromByteCount: Int64(dataSaved))

        return NetShieldStatsItemModel(title: title, value: value, isEnabled: !paused)
    }
}
