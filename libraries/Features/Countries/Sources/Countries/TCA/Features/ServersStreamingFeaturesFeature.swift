//
//  Created on 20/01/2026 by Max Kupetskyi.
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

import CommonNetworking
import ComposableArchitecture
import Foundation

@Reducer
struct ServersStreamingFeaturesFeature {
    @ObservableState
    struct State: Equatable {
        let countryName: String
        var streamingServices: IdentifiedArrayOf<StreamingServiceItem.State>
    }

    enum Action {
        case streamingServices(IdentifiedActionOf<StreamingServiceItem>)
        case onAppear
    }

    @Dependency(\.propertiesManager) private var propertiesManager

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                print("ServersStreamingFeatures appeared for country: \(state.countryName)")
                return .none

            case .streamingServices:
                return .none
            }
        }
        .forEach(\.streamingServices, action: \.streamingServices) {
            StreamingServiceItem()
        }
    }
}

// MARK: - Preview/Mock Support

#if DEBUG
    extension ServersStreamingFeaturesFeature.State {
        @MainActor static let mock = ServersStreamingFeaturesFeature.State(
            countryName: "Country",
            streamingServices: [
                .init(service: VpnStreamingOption(name: "Netflix", icon: "netflix.png"), showImage: true),
                .init(service: VpnStreamingOption(name: "Amazon Prime", icon: "amazonprime.png"), showImage: true),
                .init(service: VpnStreamingOption(name: "DisneyPlus", icon: "disneyplus.png"), showImage: true),
            ]
        )

        @MainActor static let singleService = ServersStreamingFeaturesFeature.State(
            countryName: "United States",
            streamingServices: [
                .init(service: VpnStreamingOption(name: "Netflix", icon: "netflix.png"), showImage: true),
            ]
        )

        @MainActor static let manyServices = ServersStreamingFeaturesFeature.State(
            countryName: "United Kingdom",
            streamingServices: [
                .init(service: VpnStreamingOption(name: "Netflix", icon: "netflix.png"), showImage: true),
                .init(service: VpnStreamingOption(name: "Amazon Prime", icon: "amazonprime.png"), showImage: true),
                .init(service: VpnStreamingOption(name: "Disney+", icon: "disneyplus.png"), showImage: true),
                .init(service: VpnStreamingOption(name: "HBO Max", icon: "hbomax.png"), showImage: true),
                .init(service: VpnStreamingOption(name: "Hulu", icon: "hulu.png"), showImage: true),
                .init(service: VpnStreamingOption(name: "BBC iPlayer", icon: "bbciplayer.png"), showImage: true),
                .init(service: VpnStreamingOption(name: "YouTube", icon: "youtube.png"), showImage: true),
                .init(service: VpnStreamingOption(name: "Spotify", icon: "spotify.png"), showImage: true),
            ]
        )

        @MainActor static let fewServices = ServersStreamingFeaturesFeature.State(
            countryName: "Japan",
            streamingServices: [
                .init(service: VpnStreamingOption(name: "Netflix", icon: "netflix.png"), showImage: true),
                .init(service: VpnStreamingOption(name: "Amazon Prime", icon: "amazonprime.png"), showImage: true),
            ]
        )

        @MainActor static let empty = ServersStreamingFeaturesFeature.State(
            countryName: "Unknown",
            streamingServices: []
        )
    }
#endif
