//
//  Created on 17/10/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Domain
import Foundation
import Strings

public extension ConnectionSpec.Location {
    private func regionName(locale: Locale, code: String) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }

    func accessibilityText(locale: Locale) -> String {
        switch self {
        case .fastest:
            Localizable.connectionCardAccessibilityFastest
        case .secureCore(.fastest):
            Localizable.connectionCardAccessibilityFastestSc
        default:
            text(locale: locale)
        }
    }

    // When nil, we should use the information about the server we connected to to form the header
    func headerText(locale: Locale) -> String? {
        switch self {
        case .random:
            nil
        default:
            text(locale: locale)
        }
    }

    func text(locale: Locale) -> String {
        switch self {
        case .fastest, .secureCore(.fastest):
            Localizable.homeDefaultConnectionFastestName

        case .random, .secureCore(.random):
            Localizable.homeRecentsRandomServerTitle

        case let .region(code),
             let .exact(_, _, _, _, code),
             let .secureCore(.fastestHop(code)),
             let .secureCore(.hop(code, _)):
            regionName(locale: locale, code: code)

        case let .gateway(name):
            name
        }
    }

    func subtext(locale: Locale) -> String? {
        switch self {
        case .fastest, .random, .region:
            return nil
        case let .exact(server, _, number, subregion, _):
            var text = ""
            if case .free = server {
                text = "FREE"
            } else if let subregion {
                text = subregion
            } else {
                return nil
            }
            if let number {
                text += " #\(number)"
            }
            return text
        case .secureCore(.fastest), .secureCore(.fastestHop), .secureCore(.random):
            return Localizable.viaSecureCore
        case let .secureCore(.hop(_, via)):
            return Localizable.viaCountry(regionName(locale: locale, code: via))
        case .gateway:
            // Similarly to fastest/random/region, we're not specifying an exact server. Leave subtext blank.
            return nil
        }
    }
}
