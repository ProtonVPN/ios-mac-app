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
import Foundation
import LegacyCommon
import Strings

@Reducer
public struct ServersFeaturesInformationFeature {
    @ObservableState
    public struct State: Equatable, Sendable {
        public let showTitles: Bool
        public var sections: IdentifiedArrayOf<FeatureSection.State>

        public init(showTitles: Bool, sections: IdentifiedArrayOf<FeatureSection.State>) {
            self.showTitles = showTitles
            self.sections = sections
        }
    }

    public enum Action {
        case onAppear
        case sections(IdentifiedActionOf<FeatureSection>)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .onAppear:
                .none

            case .sections:
                .none
            }
        }
        .forEach(\.sections, action: \.sections) {
            FeatureSection()
        }
    }
}

// MARK: - FeatureSection Reducer

@Reducer
public struct FeatureSection {
    @ObservableState
    public struct State: Equatable, Identifiable, Sendable {
        public let id: Int
        public let title: String?
        public var features: IdentifiedArrayOf<ServerFeatureItem.State>

        public init(id: Int, title: String?, features: IdentifiedArrayOf<ServerFeatureItem.State>) {
            self.id = id
            self.title = title
            self.features = features
        }
    }

    public enum Action {
        case features(IdentifiedActionOf<ServerFeatureItem>)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .features:
                .none
            }
        }
        .forEach(\.features, action: \.features) {
            ServerFeatureItem()
        }
    }
}

// MARK: - Predefined Configurations

public extension ServersFeaturesInformationFeature.State {
    /// Services information showing features and performance sections
    static let servicesInfo = ServersFeaturesInformationFeature.State(
        showTitles: true,
        sections: IdentifiedArray(uniqueElements: [
            FeatureSection.State(
                id: 0,
                title: Localizable.featuresTitle,
                features: IdentifiedArray(uniqueElements: [
                    .init(featureType: .smartRouting),
                    .init(featureType: .streaming),
                    .init(featureType: .p2p),
                    .init(featureType: .tor),
                ])
            ),
            FeatureSection.State(
                id: 1,
                title: Localizable.performanceTitle,
                features: IdentifiedArray(uniqueElements: [
                    .init(featureType: .loadPerformance),
                ])
            ),
        ])
    )

    /// Gateways information showing only gateway feature
    static let gatewaysInfo = ServersFeaturesInformationFeature.State(
        showTitles: false,
        sections: IdentifiedArray(uniqueElements: [
            FeatureSection.State(
                id: 0,
                title: nil,
                features: IdentifiedArray(uniqueElements: [
                    .init(featureType: .gateway),
                ])
            ),
        ])
    )
}

// MARK: - Preview/Mock Support

#if DEBUG
    public extension ServersFeaturesInformationFeature.State {
        static let mock = ServersFeaturesInformationFeature.State(
            showTitles: true,
            sections: IdentifiedArray(uniqueElements: [
                FeatureSection.State(
                    id: 0,
                    title: Localizable.featuresTitle,
                    features: IdentifiedArray(uniqueElements: [
                        .init(featureType: .smartRouting),
                        .init(featureType: .streaming),
                        .init(featureType: .p2p),
                        .init(featureType: .tor),
                        .init(featureType: .loadPerformance),
                        .init(featureType: .freeServers),
                        .init(featureType: .gateway),
                    ])
                ),
            ])
        )

        static let multipleSections = ServersFeaturesInformationFeature.State(
            showTitles: true,
            sections: IdentifiedArray(uniqueElements: [
                FeatureSection.State(
                    id: 0,
                    title: Localizable.featuresTitle,
                    features: IdentifiedArray(uniqueElements: [
                        .init(featureType: .smartRouting),
                        .init(featureType: .streaming),
                        .init(featureType: .p2p),
                        .init(featureType: .tor),
                    ])
                ),
                FeatureSection.State(
                    id: 1,
                    title: Localizable.performanceTitle,
                    features: IdentifiedArray(uniqueElements: [
                        .init(featureType: .loadPerformance),
                    ])
                ),
            ])
        )

        static let noTitles = ServersFeaturesInformationFeature.State(
            showTitles: false,
            sections: IdentifiedArray(uniqueElements: [
                FeatureSection.State(
                    id: 0,
                    title: nil,
                    features: IdentifiedArray(uniqueElements: [
                        .init(featureType: .gateway),
                    ])
                ),
            ])
        )

        static let singleFeature = ServersFeaturesInformationFeature.State(
            showTitles: true,
            sections: IdentifiedArray(uniqueElements: [
                FeatureSection.State(
                    id: 0,
                    title: Localizable.featuresTitle,
                    features: IdentifiedArray(uniqueElements: [
                        .init(featureType: .streaming),
                    ])
                ),
            ])
        )

        static let empty = ServersFeaturesInformationFeature.State(
            showTitles: false,
            sections: []
        )
    }
#endif
