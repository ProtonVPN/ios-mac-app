//
//  Created on 2025-10-31 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies

public struct CountryCodeProviderKey: DependencyKey {
    public static let liveValue: CountryCodeProvider = CountryCodeProviderImplementation()

    public static let testValue: CountryCodeProvider = CountryCodeProviderMock()
}

public extension DependencyValues {
    var countryCodeProvider: CountryCodeProvider {
        get { self[CountryCodeProviderKey.self] }
        set { self[CountryCodeProviderKey.self] = newValue }
    }
}

struct CountryCodeProviderMock: CountryCodeProvider {
    var countryCodes: [String] = []
}
