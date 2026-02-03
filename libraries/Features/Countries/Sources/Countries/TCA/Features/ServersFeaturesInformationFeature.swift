//
//  ServersFeaturesInformationFeature.swift
//  ProtonVPN - Created on 08.01.26.
//
//  Copyright (c) 2026 Proton Technologies AG
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

import ComposableArchitecture
import Foundation
import LegacyCommon
import Strings

@Reducer
struct ServersFeaturesInformationFeature {
    @ObservableState
    struct State: Equatable {
        let showTitles: Bool
        var sections: IdentifiedArrayOf<FeatureSection.State>
    }

    enum Action {
        case onAppear
        case sections(IdentifiedActionOf<FeatureSection>)
    }

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
struct FeatureSection {
    @ObservableState
    struct State: Equatable, Identifiable {
        let id: Int
        let title: String?
        var features: IdentifiedArrayOf<ServerFeatureItem.State>
    }

    enum Action {
        case features(IdentifiedActionOf<ServerFeatureItem>)
    }

    var body: some ReducerOf<Self> {
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

extension ServersFeaturesInformationFeature.State {
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
    extension ServersFeaturesInformationFeature.State {
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
