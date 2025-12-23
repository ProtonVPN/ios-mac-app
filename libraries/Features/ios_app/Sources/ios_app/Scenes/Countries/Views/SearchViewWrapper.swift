//
//  Created on 23/12/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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

import Search
import SwiftUI
import UIKit

// Navigation destinations
enum NavigationDestination: Hashable {
    case search
    case country(CountryItemViewModel)
}

struct SearchViewWrapper: UIViewControllerRepresentable {
    let viewModel: CountriesViewModel
    @Binding var navigationPath: [NavigationDestination]

    var searchMode: SearchMode {
        if viewModel.secureCoreOn {
            return .secureCore
        }

        if viewModel.userTier?.isFreeTier == true {
            return .standard(.free)
        }
        return .standard(.plus)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let countryModels = viewModel.searchData

        let searchCoordinator = SearchCoordinator(configuration: Search.Configuration())
        searchCoordinator.delegate = context.coordinator
        let searchViewController = searchCoordinator.makeViewController(data: countryModels, mode: searchMode)

        context.coordinator.searchCoordinator = searchCoordinator

        return searchViewController
    }

    func updateUIViewController(_: UIViewController, context: Context) {
        let countryModels = viewModel.searchData
        context.coordinator.searchCoordinator?.reload(data: countryModels, mode: searchMode)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            viewModel: viewModel,
            navigationPath: $navigationPath
        )
    }

    class Coordinator: NSObject, SearchCoordinatorDelegate {
        let viewModel: CountriesViewModel
        @Binding var navigationPath: [NavigationDestination]
        var searchCoordinator: SearchCoordinator?

        init(
            viewModel: CountriesViewModel,
            navigationPath: Binding<[NavigationDestination]>
        ) {
            self.viewModel = viewModel
            self._navigationPath = navigationPath
        }

        func userDidSelectCountry(model: CountryViewModel) {
            guard let cellModel = model as? CountryItemViewModel else {
                return
            }

            // Add country to navigation path - SwiftUI NavigationStack will handle the push
            navigationPath.append(.country(cellModel))
        }

        func userDidRequestPlanPurchase() {
            viewModel.presentAllCountriesUpsell()
        }
    }
}
