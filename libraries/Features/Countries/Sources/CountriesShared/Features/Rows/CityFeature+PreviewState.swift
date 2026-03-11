//
//  Created on 10/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

#if DEBUG
    import ComposableArchitecture

    public extension CityFeature.State {
        static var previewNormal: Self {
            .init(
                cityName: "New York",
                countryCode: "US",
                servers: IdentifiedArray(uniqueElements: [.previewNormal])
            )
        }

        static var previewUpgrade: Self {
            .init(
                cityName: "Amsterdam",
                countryCode: "NL",
                servers: IdentifiedArray(uniqueElements: [.previewUpgrade])
            )
        }

        static var previewTranslated: Self {
            .init(
                cityName: "Barcelona",
                countryCode: "ES",
                servers: IdentifiedArray(uniqueElements: [.previewTranslatedCity])
            )
        }
    }
#endif
