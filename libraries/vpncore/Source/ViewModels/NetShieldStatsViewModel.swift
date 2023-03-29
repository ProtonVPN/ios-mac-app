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

    static let formatter = NetShieldStatsNumberFormatter()

    case disabled
    case enabled(adsBlocked: Int, trackersStopped: Int, bytesSaved: Int64, paused: Bool)

    public var adsModel: NetShieldStatsItemModel {
        let title: String = LocalizedString.netshieldStatsAdsBlocked

        guard case .enabled(let adsBlocked, _, _, let paused) = self else {
            return .disabled(title: title)
        }
        let value = Self.formatter.string(from: adsBlocked)
        return NetShieldStatsItemModel(title: title, value: value, isEnabled: !paused)
    }

    public var trackersModel: NetShieldStatsItemModel {
        let title: String = LocalizedString.netshieldStatsTrackersStopped

        guard case .enabled(_, let trackersStopped, _, let paused) = self else {
            return .disabled(title: title)
        }
        let value = Self.formatter.string(from: trackersStopped)
        return NetShieldStatsItemModel(title: title, value: value, isEnabled: !paused)
    }

    public var dataModel: NetShieldStatsItemModel {
        let title: String = LocalizedString.netshieldStatsDataSaved

        guard case .enabled(_, _, let dataSaved, let paused) = self else {
            return .disabled(title: title)
        }

        let value = ByteCountFormatter().string(fromByteCount: dataSaved)

        return NetShieldStatsItemModel(title: title, value: value, isEnabled: !paused)
    }
}
