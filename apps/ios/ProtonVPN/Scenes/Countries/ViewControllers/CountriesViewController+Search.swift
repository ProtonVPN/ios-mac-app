//
//  Created on 08.03.2022.
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
import Search
import LegacyCommon

extension CountriesViewController: SearchCoordinatorDelegate {
    func userDidRequestPlanPurchase() {
        viewModel.presentAllCountriesUpsell()
    }

    func userDidSelectCountry(model: CountryViewModel) {
        guard let cellModel = model as? CountryItemViewModel else {
            return
        }

        showCountry(cellModel: cellModel)
    }

    func reloadSearch() {
        coordinator?.reload(data: viewModel.searchData, mode: searchMode)
    }

    @objc func showSearch() {
        guard let navigationController = navigationController else {
            return
        }

        coordinator = SearchCoordinator(configuration: Configuration(), storage: viewModel.searchStorage)
        coordinator?.delegate = self
        coordinator?.start(navigationController: navigationController, data: viewModel.searchData, mode: searchMode)
    }

    private var searchMode: SearchMode {
        if viewModel.secureCoreOn {
            return .secureCore
        }

        switch viewModel.maxTier {
        case CoreAppConstants.VpnTiers.free:
            return .standard(.free)
        default:
            return .standard(.plus)
        }
    }
}
