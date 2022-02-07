//
//  Created on 07.02.2022.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import vpncore

protocol PaidFeatureService {
    func makePaidFeatureSelectionViewController<T>(selectedFeature: T, allFeatures: [T], title: String, callback: @escaping PaidFeatureSelectionViewModel<T>.ApproveCallback, onChange: @escaping PaidFeatureSelectionViewModel<T>.FeatureChangeCallback) -> PaidFeatureSelectionViewController<T> where T: PaidFeature
}

protocol PaidFeatureServiceFactory {
    func makePaidFeatureService() -> PaidFeatureService
}

final class PaidFeatureServiceImplementation: PaidFeatureService {
    typealias Factory = VpnKeychainFactory & PlanServiceFactory
    private var factory: Factory

    init(factory: Factory) {
        self.factory = factory
    }

    func makePaidFeatureSelectionViewController<T>(selectedFeature: T, allFeatures: [T], title: String, callback: @escaping PaidFeatureSelectionViewModel<T>.ApproveCallback, onChange: @escaping PaidFeatureSelectionViewModel<T>.FeatureChangeCallback) -> PaidFeatureSelectionViewController<T> where T: PaidFeature {
        let viewModel = PaidFeatureSelectionViewModel(selectedFeature: selectedFeature, factory: factory, shouldSelectNewValue: callback, onFeatureChange: onChange, allFeatures: allFeatures, title: title)
        return PaidFeatureSelectionViewController(viewModel: viewModel)
    }
}
