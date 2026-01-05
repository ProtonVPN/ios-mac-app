//
//  ServersStreamingFeaturesViewModel.swift
//  ProtonVPN - Created on 20.04.21.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import CommonNetworking
import Dependencies
import Foundation
import LegacyCommon

protocol ServersStreamingFeaturesViewModel {
    var countryName: String { get }
    var columnsAmount: Int { get }
    var totalRows: Int { get }
    var totalItems: Int { get }

    func vpnOption(for index: Int) -> VpnStreamingOption
}

class ServersStreamingFeaturesViewModelImplementation: ServersStreamingFeaturesViewModel {
    private let streamingServices: [VpnStreamingOption]

    init(country: String, streamServices: [VpnStreamingOption]) {
        self.countryName = country
        self.streamingServices = streamServices
    }

    let columnsAmount: Int = 4

    var totalRows: Int {
        Int((Float(streamingServices.count) / Float(columnsAmount)).rounded(.up))
    }

    let countryName: String

    var totalItems: Int {
        streamingServices.count
    }

    func vpnOption(for index: Int) -> VpnStreamingOption {
        streamingServices[index]
    }
}

#if DEBUG
    extension ServersStreamingFeaturesViewModelImplementation {
        static let mock = ServersStreamingFeaturesViewModelImplementation(
            country: "Country",
            streamServices: [
                VpnStreamingOption(name: "Netflix", icon: "netflix.png"),
                VpnStreamingOption(name: "Amazon Prime", icon: "amazonprime.png"),
                VpnStreamingOption(name: "DisneyPlus", icon: "disneyplus.png"),
            ]
        )

        static let singleService = ServersStreamingFeaturesViewModelImplementation(
            country: "United States",
            streamServices: [
                VpnStreamingOption(name: "Netflix", icon: "netflix.png"),
            ]
        )

        static let manyServices = ServersStreamingFeaturesViewModelImplementation(
            country: "United Kingdom",
            streamServices: [
                VpnStreamingOption(name: "Netflix", icon: "netflix.png"),
                VpnStreamingOption(name: "Amazon Prime", icon: "amazonprime.png"),
                VpnStreamingOption(name: "Disney+", icon: "disneyplus.png"),
                VpnStreamingOption(name: "HBO Max", icon: "hbomax.png"),
                VpnStreamingOption(name: "Hulu", icon: "hulu.png"),
                VpnStreamingOption(name: "BBC iPlayer", icon: "bbciplayer.png"),
                VpnStreamingOption(name: "YouTube", icon: "youtube.png"),
                VpnStreamingOption(name: "Spotify", icon: "spotify.png"),
            ]
        )

        static let fewServices = ServersStreamingFeaturesViewModelImplementation(
            country: "Japan",
            streamServices: [
                VpnStreamingOption(name: "Netflix", icon: "netflix.png"),
                VpnStreamingOption(name: "Amazon Prime", icon: "amazonprime.png"),
            ]
        )
    }
#endif
