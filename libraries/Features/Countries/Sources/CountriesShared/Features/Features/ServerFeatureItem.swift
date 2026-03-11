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
import Strings
import Theme

// MARK: - Feature Type Enum

public enum ServerFeatureType: String, Equatable, Hashable, Sendable {
    case smartRouting
    case streaming
    case p2p
    case tor
    case loadPerformance
    case freeServers
    case gateway

    public var icon: ImageAsset.Image {
        switch self {
        case .smartRouting:
            Theme.Asset.Icons.globe.image
        case .streaming:
            Theme.Asset.Icons.play.image
        case .p2p:
            Theme.Asset.Icons.arrowsSwitch.image
        case .tor:
            Theme.Asset.Icons.brandTor.image
        case .loadPerformance, .freeServers:
            Theme.Asset.Icons.servers.image
        case .gateway:
            Theme.Asset.Icons.globe.image
        }
    }

    public var title: String {
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

    public var description: String {
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

    public var footer: String? {
        switch self {
        case .smartRouting, .streaming, .p2p, .tor, .loadPerformance:
            Localizable.learnMore
        case .freeServers, .gateway:
            nil
        }
    }

    public var urlContact: VPNLink? {
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

    public var displayLoads: Bool {
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
public struct ServerFeatureItem {
    public init() {}

    @ObservableState
    public struct State: Equatable, Identifiable, Sendable {
        let featureType: ServerFeatureType

        public init(featureType: ServerFeatureType) {
            self.featureType = featureType
        }

        public var id: String {
            featureType.rawValue
        }

        public var icon: ImageAsset.Image {
            featureType.icon
        }

        public var title: String {
            featureType.title
        }

        public var description: String {
            featureType.description
        }

        public var footer: String? {
            featureType.footer
        }

        public var urlContact: VPNLink? {
            featureType.urlContact
        }

        public var displayLoads: Bool {
            featureType.displayLoads
        }

        public var hasLearnMore: Bool {
            footer != nil && urlContact != nil
        }
    }

    public enum Action {
        case learnMoreTapped
    }

    @Dependency(\.linkOpener) private var linkOpener

    public var body: some ReducerOf<Self> {
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
