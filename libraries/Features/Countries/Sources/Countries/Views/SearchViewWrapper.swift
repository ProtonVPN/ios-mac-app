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

import Dependencies
import Persistence
import Search
import SwiftUI
import UIKit

// Navigation destinations
enum NavigationDestination: Hashable {
    case search
    case country(String) // Country name
}

struct SearchViewWrapper: UIViewControllerRepresentable {
    let secureCoreOn: Bool
    let userTier: String
    let searchData: [CountryViewModel]
    @Binding var navigationPath: [NavigationDestination]

    var searchMode: SearchMode {
        if secureCoreOn {
            return .secureCore
        }

        if userTier == "free" {
            return .standard(.free)
        }
        return .standard(.plus)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let searchCoordinator = SearchCoordinator(configuration: Search.Configuration())
        searchCoordinator.delegate = context.coordinator
        let searchViewController = searchCoordinator.makeViewController(data: searchData, mode: searchMode)

        context.coordinator.searchCoordinator = searchCoordinator

        return searchViewController
    }

    func updateUIViewController(_: UIViewController, context: Context) {
        context.coordinator.searchCoordinator?.reload(data: searchData, mode: searchMode)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            navigationPath: $navigationPath
        )
    }

    final class Coordinator: NSObject, SearchCoordinatorDelegate {
        @Binding var navigationPath: [NavigationDestination]
        var searchCoordinator: SearchCoordinator?

        init(
            navigationPath: Binding<[NavigationDestination]>
        ) {
            self._navigationPath = navigationPath
        }

        func userDidSelectCountry(model: CountryViewModel) {
            print("Country selected in search: \(model)")
            // Add country to navigation path - SwiftUI NavigationStack will handle the push
            navigationPath.append(.country("Selected Country"))
        }

        func userDidRequestPlanPurchase() {
            print("Plan purchase requested")
        }
    }
}

private extension Search.Configuration {
    init() {
        @Dependency(\.serverRepository) var repository
        self.init(constants: Constants(numberOfCountries: repository.countryCount()))
    }
}
