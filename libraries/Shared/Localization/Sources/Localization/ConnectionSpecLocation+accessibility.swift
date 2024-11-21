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
            return "The fastest country available"
        case .secureCore(.fastest):
            return "The fastest secure core country available"
        default:
            return text(locale: locale)
        }
    }

    // When nil, we should use the information about the server we connected to to form the header
    func headerText(locale: Locale) -> String? {
        switch self {
        case .random:
            return nil
        default:
            return text(locale: locale)
        }
    }

    func text(locale: Locale) -> String {
        switch self {
        case .fastest, .secureCore(.fastest):
            return "Fastest country"

        case .random, .secureCore(.random):
            return "Random server"

        case .region(let code),
                .exact(_, _, _, let code),
                .secureCore(.fastestHop(let code)),
                .secureCore(.hop(let code, _)):
            return regionName(locale: locale, code: code)
        }
    }

    func subtext(locale: Locale) -> String? {
        switch self {
        case .fastest, .random, .region, .secureCore(.random):
            return nil
        case let .exact(server, number, subregion, _):
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
        case .secureCore(.fastest), .secureCore(.fastestHop):
            return Localizable.viaSecureCore
        case .secureCore(.hop(_, let via)):
            return Localizable.viaCountry(regionName(locale: locale, code: via))
        }
    }
}
