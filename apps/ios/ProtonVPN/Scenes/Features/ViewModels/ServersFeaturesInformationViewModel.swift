//
//  ServersFeaturesInformationViewModel.swift
//  ProtonVPN - Created on 21.04.21.
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

import UIKit
import LegacyCommon
import Strings

protocol ServersFeaturesInformationViewModel {
    func titleFor( _ section: Int ) -> String?
    func featuresCount(for section: Int) -> Int
    func getFeatureViewModel( indexPath: IndexPath ) -> FeatureCellViewModel
    var totalFeatures: Int { get }
    var headerHeight: CGFloat { get }
}

struct ServersFeaturesInformationViewModelImplementation: ServersFeaturesInformationViewModel {
    static let servicesInfo = Self(
        showTitles: true,
        features: [
            [
                SmartRoutingFeatureCellViewModel(),
                StreamingFeatureCellViewModel(),
                P2PFeatureCellViewModel(),
                TorFeatureCellViewModel()
            ],
            [
                LoadPerformanceFeatureCellViewModel()
            ]
        ]
    )

    static let gatewaysInfo = Self(showTitles: false, features: [[GatewayFeatureCellViewModel()]])

    let showTitles: Bool
    let features: [[FeatureCellViewModel]]

    // MARK: - ServersFeaturesInformationViewModel
    
    let headerHeight: CGFloat = 52
    
    var totalFeatures: Int {
        return features.count
    }
    
    func featuresCount(for section: Int) -> Int {
        return features[section].count
    }
    
    func getFeatureViewModel(indexPath: IndexPath) -> FeatureCellViewModel {
        return features[indexPath.section][indexPath.row]
    }
    
    func titleFor(_ section: Int) -> String? {
        guard showTitles else { return nil }

        return section == 0 ? Localizable.featuresTitle : Localizable.performanceTitle
    }
}
