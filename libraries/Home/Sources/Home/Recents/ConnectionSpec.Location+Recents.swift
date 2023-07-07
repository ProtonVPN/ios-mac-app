//
//  Created on 09/06/2023.
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
import VPNAppCore
import Theme

extension ConnectionSpec.Location {
    private func regionName(locale: Locale, code: String) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }

    public func accessibilityText(locale: Locale) -> String {
        switch self {
        case .fastest:
            return "The fastest country available"
        case .secureCore(.fastest):
            return "The fastest secure core country available"
        default:
            // todo: .exact and .region should specify number and ideally features as well
            return text(locale: locale)
        }
    }

    public func text(locale: Locale) -> String {
        switch self {
        case .fastest,
                .secureCore(.fastest):
            return "Fastest"
        case .region(let code),
                .exact(_, _, _, let code),
                .secureCore(.fastestHop(let code)),
                .secureCore(.hop(let code, _)):
            return regionName(locale: locale, code: code)
        }
    }

    public func subtext(locale: Locale) -> String? {
        switch self {
        case .fastest, .region, .secureCore(.fastest), .secureCore(.fastestHop):
            return nil
        case let .exact(server, number, subregion, _):
            if server == .free {
                return "FREE#\(number)"
            } else if let subregion {
                return "\(subregion) #\(number)"
            } else {
                return nil
            }
        case .secureCore(.hop(_, let via)):
            return "via \(regionName(locale: locale, code: via))"
        }
    }


    public var flag: any FlagView {
        switch self {
        case .fastest:
            return FastestFlagView(secureCore: false)
        case .region(let code):
            return SimpleFlagView(regionCode: code)
        case .exact(_, _, _, let code):
            return SimpleFlagView(regionCode: code)
        case .secureCore(let secureCoreSpec):
            switch secureCoreSpec {
            case .fastest:
                return FastestFlagView(secureCore: true)
            case let .fastestHop(code):
                return SecureCoreFlagView(regionCode: code, viaRegionCode: nil)
            case let .hop(code, via):
                return SecureCoreFlagView(regionCode: code, viaRegionCode: via)
            }
        }
    }
}
