//
//  FeaturesOverlayViewModel.swift
//  ProtonVPN - Created on 22.04.21.
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

import Foundation
import LegacyCommon

protocol FeaturesOverlayViewModelProtocol {
    var title: String { get }
    var featureViewModels: [FeatureCellViewModel] { get }
}

struct PremiumFeaturesOverlayViewModel: FeaturesOverlayViewModelProtocol {
    let title: String = LocalizedString.featuresTitle
    var featureViewModels: [FeatureCellViewModel] {
        [SmartRoutingFeature(), StreamingFeature(), P2PFeature(), TorFeature()]
    }
}

struct FreeFeaturesOverlayViewModel: FeaturesOverlayViewModelProtocol {
    let title: String = LocalizedString.informationTitle
    let featureViewModels: [FeatureCellViewModel]
    init(featureViewModels: [FeatureCellViewModel]) {
        self.featureViewModels = featureViewModels
    }
}

struct GatewayFeaturesOverlayViewModel: FeaturesOverlayViewModelProtocol {
    let title: String = LocalizedString.locationsGateways
    var featureViewModels: [FeatureCellViewModel] {
        [GatewayFeature()]
    }
}
