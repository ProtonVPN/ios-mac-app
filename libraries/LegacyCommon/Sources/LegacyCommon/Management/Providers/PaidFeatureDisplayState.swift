//
//  Created on 18/08/2023.
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

// Display state for toggleable features
public enum PaidFeatureDisplayState: Equatable {

    /// Feature should be shown as available
    /// - parameters:
    ///   - enabled: The current value of the feature (on/off)
    ///   - interactive: Whether the user is able to turn the feature on/off
    case available(enabled: Bool, interactive: Bool)

    /// Feature should be shown as requiring an upgrade
    case upsell

    /// Don't display any UI. Feature disabled by feature flags or OS version
    case disabled
}
