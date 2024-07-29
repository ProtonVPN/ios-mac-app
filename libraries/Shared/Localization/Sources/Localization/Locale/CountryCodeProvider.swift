//
//  Created on 28/02/2024.
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

import Foundation
import Strings
import ProtonCoreUtilities // Array and Dictionary extensions

#if canImport(CoreTelephony)
import CoreTelephony
#endif

public protocol CountryCodeProvider {
    var countryCodes: [String] { get }
}

public protocol CountryCodeProviderFactory {
    func makeCountryCodeProvider() -> CountryCodeProvider
}

public class CountryCodeProviderImplementation: CountryCodeProvider {
    public private(set) var countryCodes: [String]

    private static let localeResolver = LocaleResolverImplementation.default

    /// Insert the region code if it's available for the current locale.
    /// Then, go over all of the preferred languages on a device. If we're able
    /// to generate a locale from this language, then insert its region code
    /// into the set as well.
    public init() {
        var result: [String] = []

        if let localeTag = Self.localeResolver.currentLocale.ietfRegionTag {
            result.append(localeTag.lowercased())
        }

        for language in Self.localeResolver.preferredLanguages {
            let languageLocale = Self.localeResolver.locale(withIdentifier: language)

            if let tag = languageLocale.ietfRegionTag?.lowercased() {
                result.append(tag)
            }
        }

        self.countryCodes = result
            .appending(Array(Self.carrierIsoCountryCodes))
            .uniqued
    }

    /// Only available on iOS devices before iOS 16, where this functionality was senselessly deprecated.
    private static var carrierIsoCountryCodes: Set<String> {
        #if os(iOS)
        guard #unavailable(iOS 16) else {
            return []
        }

        let netInfo = CTTelephonyNetworkInfo()
        guard let carriers = netInfo.serviceSubscriberCellularProviders else {
            return []
        }

        return carriers.values.reduce(into: Set()) { partialResult, carrier in
            guard let iso = carrier.isoCountryCode, iso != "--" else {
                return
            }
            partialResult.insert(iso.lowercased())
        }
        #else
        return []
        #endif
    }
}
