//
//  Created on 13/03/2025.
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

import Foundation

public struct SettingsDimensions: Encodable {
    let defaultConnectionType: DefaultConnectionType
    let appIcon: AppIcon
    let userTier: UserTier
    let widgetCount: WidgetCount
    let firstWidgetSize: WidgetSize
    let isIPv6Enabled: Bool

    init(defaultConnectionType: DefaultConnectionType,
         appIcon: AppIcon,
         userTier: UserTier,
         widgetCount: WidgetCount,
         firstWidgetSize: WidgetSize,
         isIPv6Enabled: Bool) {
        self.defaultConnectionType = defaultConnectionType
        self.appIcon = appIcon
        self.userTier = userTier
        self.widgetCount = widgetCount
        self.firstWidgetSize = firstWidgetSize
        self.isIPv6Enabled = isIPv6Enabled
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultConnectionType, forKey: .defaultConnectionType)
        try container.encode(appIcon, forKey: .appIcon)
        try container.encode(userTier, forKey: .userTier)
        try container.encode(widgetCount, forKey: .widgetCount)
        try container.encode(firstWidgetSize, forKey: .firstWidgetSize)
        try container.encode(isIPv6Enabled, forKey: .isIPv6Enabled)
    }

    enum CodingKeys: String, CodingKey {
        case defaultConnectionType = "default_connection_type"
        case appIcon = "app_icon"
        case userTier = "user_tier"
        case widgetCount = "widget_count"
        case firstWidgetSize = "first_widget_size"
        case isIPv6Enabled = "is_ipv6_enabled"
    }

    public enum DefaultConnectionType: String, Encodable {
        case fastest
        case lastConnection = "last_connection"
        case recent
    }

    public enum AppIcon: String, Encodable {
        case `default`
        case dark
        case retro
        case weather
        case notes
        case calculator
    }

    public enum UserTier: String, Encodable {
        case nonUser = "non-user"
        case free
        case paid
        case internalTier = "internal"
        case credentialLess = "credential-less"
    }

    public enum WidgetCount: String, Encodable {
        case zero = "0"
        case one = "1"
        case twoToFour = "2-4"
        case greaterOrEqualFive = ">=5"
    }

    public enum WidgetSize: String, Encodable {
        case small
        case medium
        case large
    }

}
