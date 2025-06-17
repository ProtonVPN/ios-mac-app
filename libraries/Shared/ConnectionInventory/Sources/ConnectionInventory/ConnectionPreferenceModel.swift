//
//  Created on 2025-01-28.
//
//  Copyright (c) 2025 Proton AG
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

import Collections
import ComposableArchitecture
import Domain
import Foundation
import SharedViews
import Strings

public struct ConnectionPreferenceModel: Equatable, Hashable {
    public let preference: DefaultConnectionPreference
    public let locationFeatureModel: LocationFeatureModel

    public func hash(into hasher: inout Hasher) {
        hasher.combine(preference.hashValue)
    }

    public static let staticPreferenceModels: [Self] = [
        ConnectionPreferenceModel(
            preference: .fastest,
            locationFeatureModel: LocationFeatureModel(
                flag: .fastest,
                header: .init(title: Localizable.homeDefaultConnectionFastestName, showConnectedPin: false),
                subheader: .textual(.withoutFeatures(location: Localizable.homeDefaultConnectionFastestDescription))
            )
        ),
        ConnectionPreferenceModel(
            preference: .mostRecent,
            locationFeatureModel: .init(
                flag: .mostRecent,
                header: .init(title: Localizable.homeDefaultConnectionMostRecentName, showConnectedPin: false),
                subheader: .textual(.withoutFeatures(location: Localizable.homeDefaultConnectionMostRecentDescription))
            )
        ),
    ]
}
