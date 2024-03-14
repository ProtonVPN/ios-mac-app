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

#if DEBUG
import Foundation
import Localization

fileprivate let locales: [String: LocaleWrapperMock] = [
    "en-US": LocaleWrapperMock(
        ietfRegionTag: "us",
        regionCodeDict: [
            "US": "Murica",
        ]),
    "en": LocaleWrapperMock(
        ietfRegionTag: "ch",
        regionCodeDict: [
            "CH": "Switzerland",
            "US": "United States",
            "FR": "France"
        ]),
    "fr": LocaleWrapperMock(
        ietfRegionTag: "ch",
        regionCodeDict: [
        "CH": "Suisse",
        "US": "Etats-Unis"
        ])
]

public class LocaleResolverMock: LocaleResolver {
    public var preferredLanguages: [String] = []

    public var currentLocale: LocaleWrapper = locales["fr"]!

    public func locale(withIdentifier identifier: String) -> LocaleWrapper {
        locales[identifier]!
    }

    public init(preferredLanguages: [String], currentLocale: LocaleWrapper) {
        self.preferredLanguages = preferredLanguages
        self.currentLocale = currentLocale
    }

    public init() {
    }
}

public struct LocaleWrapperMock: LocaleWrapper {
    public let ietfRegionTag: String?

    public let regionCodeDict: [String: String]

    public func localizedString(forRegionCode regionCode: String) -> String? {
        regionCodeDict[regionCode]
    }

    public init(ietfRegionTag: String?, regionCodeDict: [String : String]) {
        self.ietfRegionTag = ietfRegionTag
        self.regionCodeDict = regionCodeDict
    }
}
#endif
