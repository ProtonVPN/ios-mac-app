//
//  Created on 2026-02-05.
//
//  Copyright (c) 2025 Proton AG
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

import CountriesShared

public typealias CountriesMainFeature = CountriesShared.CountriesMainFeature
public typealias CityStateListType = CountriesShared.CityStateListType

#if canImport(Countries_macOS)

    import Countries_macOS

    public typealias CityStateListFeature = Countries_macOS.CityStateListFeature
    public typealias CityStateListView = Countries_macOS.CityStateListView

    public typealias CountriesListFeature = Countries_macOS.CountriesListFeature
    public typealias CountriesListView = Countries_macOS.CountriesListView

#endif

#if canImport(Countries_iOS)
    import Countries_iOS

    public typealias CountriesMainView = Countries_iOS.CountriesMainView

#endif
