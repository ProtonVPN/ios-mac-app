//
//  LocalizationUtility.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public class LocalizationUtility {
    public static let `default` = LocalizationUtility()

    /// This needs to be set to public so the unit tests can change it.
    public static var localeResolver = LocaleResolverImplementation.default

    private var countryNameCache: [String: String] = [:]

    public init() {
        loadShortNames()
    }

    public func shortenIfNeeded(_ name: String) -> String {
        return namesToShorten[name] ?? name
    }

    /// First, try to get the user's first preferred language, and return the country name for that language.
    ///
    /// - If we can't find the country name for the user's first language, try finding the country name for a more standard
    ///   variant of that language.
    /// - If somehow there isn't any first preferred language, or the above country lookup fails, fallback on the current locale.
    /// - Finally, if all else fails, return nothing.
    private func countryNameUncached(forCode countryCode: String) -> String? {
        if let language = Self.localeResolver.preferredLanguages.first {
            if let countryName = Self.localeResolver.locale(withIdentifier: language).localizedString(forRegionCode: countryCode) {
                return countryName
            } else if let standardLanguage = language.components(separatedBy: "-").first,
                      let countryName = Self.localeResolver.locale(withIdentifier: standardLanguage).localizedString(forRegionCode: countryCode) {
                return countryName
            }
        }

        if let countryName = Self.localeResolver.currentLocale.localizedString(forRegionCode: countryCode) {
            return countryName
        }

        return nil
    }

    public func countryName(forCode countryCode: String) -> String? {
        if let name = countryNameCache[countryCode] {
            return name
        }

        guard let name = countryNameUncached(forCode: countryCode) else {
            return nil
        }

        let shortened = shortenIfNeeded(name)
        countryNameCache[countryCode] = shortened
        return shortened
    }

    // MARK: - Name shortening

    private var namesToShorten = [String: String]()

    private func loadShortNames() {
        do {
            guard let resource = Bundle.main.url(forResource: "country-names", withExtension: "plist") else {
                return
            }

            let data = try Data(contentsOf: resource)
            let decoder = PropertyListDecoder()
            namesToShorten = try decoder.decode([String: String].self, from: data)
        } catch {
            namesToShorten = [String: String]()
        }
    }

}
