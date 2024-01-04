//
//  Created on 2022-06-27.
//
//  Copyright (c) 2022 Proton AG
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

public protocol LocaleResolver {
    var preferredLanguages: [String] { get }
    var currentLocale: LocaleWrapper { get }

    func locale(withIdentifier: String) -> LocaleWrapper
}

public protocol LocaleWrapper {
    var ietfRegionTag: String? { get }

    func localizedString(forRegionCode: String) -> String?
}

public class LocaleResolverImplementation: LocaleResolver {
    public static var `default`: LocaleResolver = LocaleResolverImplementation()

    public var preferredLanguages: [String] {
        Locale.preferredLanguages
    }

    public var currentLocale: LocaleWrapper {
        Locale.current
    }

    public func locale(withIdentifier identifier: String) -> LocaleWrapper {
        Locale(identifier: identifier)
    }
}

extension Locale: LocaleWrapper {
    public var ietfRegionTag: String? {
        if #available(iOS 16, macOS 13, *) {
            return self.language.region?.identifier
        } else {
            return self.regionCode
        }
    }
    
    public var isRTLLanguage: Bool {
        if #available(iOS 16, macOS 13, *) {
            return self.language.characterDirection == .rightToLeft
        }
        return false
    }
}
