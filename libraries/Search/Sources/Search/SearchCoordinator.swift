//
//  Created on 02.03.2022.
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
import UIKit

public protocol SearchCoordinatorDelegate: AnyObject {
    func userDidSelectCountry(model: CountryViewModel)
    func userDidRequestPlanPurchase()
}

public final class SearchCoordinator {
    private let storyboard: UIStoryboard
    private let recentSearchesService: RecentSearchesService
    private let configuration: Configuration
    private var searchViewController: SearchViewController?

    public weak var delegate: SearchCoordinatorDelegate?

    // MARK: Setup

    public init(configuration: Configuration, storage: SearchStorage) {
        self.configuration = configuration

        colors = configuration.colors
        recentSearchesService = RecentSearchesService(storage: storage)
        storyboard = UIStoryboard(name: "Storyboard", bundle: Bundle.module)
    }

    // MARK: Actions

    public func start(navigationController: UINavigationController, data: [CountryViewModel], mode: SearchMode) {
        let searchViewController = storyboard.instantiate(controllerType: SearchViewController.self)
        searchViewController.delegate = self
        searchViewController.viewModel = SearchViewModel(recentSearchesService: recentSearchesService, data: data, constants: configuration.constants, mode: mode)
        navigationController.pushViewController(searchViewController, animated: true)
        self.searchViewController = searchViewController
    }

    public func reload(data: [CountryViewModel], mode: SearchMode) {
        guard let searchViewController = searchViewController else {
            return
        }

        searchViewController.viewModel.reload(data: data, mode: mode)
        searchViewController.reload()
    }
}

extension SearchCoordinator: SearchViewControllerDelegate {
    func userDidRequestPlanPurchase() {
        delegate?.userDidRequestPlanPurchase()
    }

    public func userDidSelectCountry(model: CountryViewModel) {
        delegate?.userDidSelectCountry(model: model)
    }
}
