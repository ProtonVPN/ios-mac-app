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

import ComposableArchitecture
import Domain
import ProtonCoreUIFoundations
import Strings
import Theme

// MARK: - Feature Type Enum

enum ServerFeatureType: String, Equatable, Hashable {
    case smartRouting
    case streaming
    case p2p
    case tor
    case loadPerformance
    case freeServers
    case gateway

    var icon: ImageAsset.Image {
        switch self {
        case .smartRouting:
            IconProvider.globe
        case .streaming:
            IconProvider.play
        case .p2p:
            IconProvider.arrowsSwitch
        case .tor:
            IconProvider.brandTor
        case .loadPerformance, .freeServers:
            IconProvider.servers
        case .gateway:
            IconProvider.globe
        }
    }

    var title: String {
        switch self {
        case .smartRouting:
            Localizable.smartRoutingTitle
        case .streaming:
            Localizable.streamingTitle
        case .p2p:
            Localizable.p2pTitle
        case .tor:
            Localizable.featureTor
        case .loadPerformance:
            Localizable.serverLoadTitle
        case .freeServers:
            Localizable.featureFreeServers
        case .gateway:
            Localizable.gatewaysModalTitle
        }
    }

    var description: String {
        switch self {
        case .smartRouting:
            Localizable.featureSmartRoutingDescription
        case .streaming:
            Localizable.featureStreamingDescription
        case .p2p:
            Localizable.featureP2pDescription
        case .tor:
            Localizable.featureTorDescription
        case .loadPerformance:
            Localizable.performanceLoadDescription
        case .freeServers:
            Localizable.featureFreeServersDescription
        case .gateway:
            Localizable.gatewaysModalText
        }
    }

    var footer: String? {
        switch self {
        case .smartRouting, .streaming, .p2p, .tor, .loadPerformance:
            Localizable.learnMore
        case .freeServers, .gateway:
            nil
        }
    }

    var urlContact: VPNLink? {
        switch self {
        case .smartRouting:
            .learnMoreSmartRouting
        case .streaming:
            .learnMoreStreaming
        case .p2p:
            .learnMoreP2p
        case .tor:
            .learnMoreTor
        case .loadPerformance:
            .learnMoreLoads
        case .freeServers:
            nil
        case .gateway:
            .dedicatedIps
        }
    }

    var displayLoads: Bool {
        switch self {
        case .loadPerformance:
            true
        default:
            false
        }
    }
}

// MARK: - FeatureItem Reducer

@Reducer
struct ServerFeatureItem {
    @ObservableState
    struct State: Equatable, Identifiable {
        let featureType: ServerFeatureType

        var id: String {
            featureType.rawValue
        }

        var icon: ImageAsset.Image {
            featureType.icon
        }

        var title: String {
            featureType.title
        }

        var description: String {
            featureType.description
        }

        var footer: String? {
            featureType.footer
        }

        var urlContact: VPNLink? {
            featureType.urlContact
        }

        var displayLoads: Bool {
            featureType.displayLoads
        }

        var hasLearnMore: Bool {
            footer != nil && urlContact != nil
        }
    }

    enum Action {
        case learnMoreTapped
    }

    @Dependency(\.linkOpener) private var linkOpener

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .learnMoreTapped:
                guard let url = state.urlContact else {
                    return .none
                }
                linkOpener.open(url)
                return .none
            }
        }
    }
}
