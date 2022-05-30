//
//  LocalizationUtility.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public class LocalizationUtility {
    public static let `default` = LocalizationUtility()

    private var countryNameCache: [String: String] = [:]

    public init() {
        loadShortNames()
    }
    
    public func shortenIfNeeded(_ name: String) -> String {
        return namesToShorten[name] ?? name
    }

    /// First, try and get the country name from the current locale.
    ///
    /// - If that fails, try and get the country name from the locale represented by the first preferred language.
    /// - If *that* fails, standardize the language by removing the bits after the "-" in the language name
    ///   (for example, fr-CH becomes fr, en-US becomes en, etc), then try getting the country name with that.
    /// - Finally, if that fails, return nothing.
    private func countryNameUncached(forCode countryCode: String) -> String? {
        if let countryName = Locale.current.localizedString(forRegionCode: countryCode) {
            return countryName
        } else if let language = Locale.preferredLanguages.first {
            if let countryName = Locale(identifier: language).localizedString(forRegionCode: countryCode) {
                return countryName
            } else if let standardLanguage = language.components(separatedBy: "-").first,
                      let countryName = Locale(identifier: standardLanguage).localizedString(forRegionCode: countryCode) {
                return countryName
            }
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
            let data = try Data(contentsOf: Bundle.main.url(forResource: "country-names", withExtension: "plist")!)
            let decoder = PropertyListDecoder()
            namesToShorten = try decoder.decode([String: String].self, from: data)
        } catch {
            namesToShorten = [String: String]()
        }
    }
    
}
