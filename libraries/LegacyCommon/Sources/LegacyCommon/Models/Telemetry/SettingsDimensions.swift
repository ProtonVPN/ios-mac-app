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

import Ergonomics

/// Each optional value in this struct has to be marked with `NAEncodable` to ensure we don't send "null" as a value, but `n/a` instead.
public struct SettingsDimensions: Encodable {
    let defaultConnectionType: DefaultConnectionType
    let appIcon: AppIcon
    let userTier: CommonTelemetryDimensions.UserTier
    @NAEncodable var widgetCount: WidgetCount?
    @NAEncodable var firstWidgetSize: WidgetSize?
    let isIPv6Enabled: IsIPv6Enabled
    let hermesCount: HermesCount
    @NAEncodable var firstHermesAddressFamily: HermesAddressFamily?
    let isHermesEnabled: HermesEnabled
    @NAEncodable var isSystemCustomDNSEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case defaultConnectionType = "default_connection_type"
        case appIcon = "app_icon"
        case userTier = "user_tier"
        case widgetCount = "widget_count"
        case firstWidgetSize = "first_widget_size"
        case isIPv6Enabled = "is_ipv6_enabled"
        case hermesCount = "custom_dns_count"
        case firstHermesAddressFamily = "first_custom_dns_address_family"
        case isHermesEnabled = "is_custom_dns_enabled"
        case isSystemCustomDNSEnabled = "is_system_custom_dns_enabled"
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

    public enum WidgetCount: String, Encodable {
        case zero = "0"
        case one = "1"
        case twoToFour = "2-4"
        case greaterOrEqualFive = ">=5"
    }

    public enum HermesCount: String, Encodable {
        case zero = "0"
        case one = "1"
        case twoToFour = "2-4"
        case greaterOrEqualFive = ">=5"

        public init(count: Int) {
            switch count {
            case 0:
                self = .zero
            case 1:
                self = .one
            case 2 ... 4:
                self = .twoToFour
            default:
                self = .greaterOrEqualFive
            }
        }
    }

    public enum HermesAddressFamily: String, Encodable {
        case ipv4
        case ipv6
    }

    public enum HermesEnabled: String, Encodable {
        case `true`
        case `false`
    }

    public enum WidgetSize: String, Encodable {
        case small
        case medium
        case large
    }

    public enum IsIPv6Enabled: String, Encodable {
        case `true`
        case `false`
    }
}

extension SettingsDimensions: CustomDebugStringConvertible {
    public var debugDescription: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let encoded = try? encoder.encode(self),
              let description = String(data: encoded, encoding: .utf8) else { return "Couldn't decode settings dimensions" }
        return description
    }
}
