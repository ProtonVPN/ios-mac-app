//
//  Created on 2022-11-22.
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

#if canImport(CoreTelephony)
import CoreTelephony
#endif

public protocol CountryCodeProvider {
    var countryCodes: [String] { get }
}

public protocol CountryCodeProviderFactory {
    func makeCountryCodeProvider() -> CountryCodeProvider
}

extension Container: CountryCodeProviderFactory {
    public func makeCountryCodeProvider() -> CountryCodeProvider {
        CountryCodeProviderImplementation()
    }
}

public class CountryCodeProviderImplementation: CountryCodeProvider {
    public var countryCodes: [String]

    private static let localeResolver = LocaleResolverImplementation.default

    /// Go over all of the preferred languages on a device. If we're able
    /// to generate a locale from this language, then insert its region code
    /// into the set.
    ///
    /// If we're on iOS, also go over the MCCs available from CoreTelephony
    /// and include those. The region codes will be uniqued and made available
    /// through the `countryCodes` property.
    public init() {
        var result = Set<String>()

        for language in Self.localeResolver.preferredLanguages {
            let languageLocale = Self.localeResolver.locale(withIdentifier: language)

            if let tag = languageLocale.ietfRegionTag {
                result.insert(tag)
            }
        }

        #if os(iOS)
        let netInfo = CTTelephonyNetworkInfo()
        if let carriers = netInfo.serviceSubscriberCellularProviders {
            for carrier in carriers.values {
                if let mcc = carrier.mobileCountryCode {
                    result.insert(mcc)
                }
            }
        }
        #endif

        self.countryCodes = Array(result)
    }
}
