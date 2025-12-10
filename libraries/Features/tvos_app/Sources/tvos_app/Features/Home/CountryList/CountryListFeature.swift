//
//  Created on 23/05/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Dependencies

import CommonNetworking
import ComposableArchitecture
import Domain
import Foundation

@Reducer
struct CountryListFeature {
    /// More info about recommended countries selection:
    /// https://confluence.protontech.ch/pages/viewpage.action?pageId=128215858#Productmetricsforbusiness-Streaming
    static let recommendedCountries: [String] = ["US", "UK", "CA", "FR", "DE"]

    @ObservableState
    struct State: Equatable {
        var recommendedSection: CountryListSection
        var countriesSection: CountryListSection
        var focusedIndex: CountryListView.ItemCoordinate? = .fastest

        @Presents var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?

        init() {
            @Dependency(\.serverRepository) var repository
            let allCountries = repository
                .getGroups(filteredBy: [
                    .isNotUnderMaintenance,
                    .kind(.country),
                ], groupedBy: .serverType)
                .enumerated()
                .compactMap { index, group in
                    group.item(index: index, section: 1)
                }

            let recommendedCountries: [CountryListItem] = CountryListFeature.recommendedCountries
                .filter { code in allCountries.contains { $0.code == code } } // be sure we can actually connect to that country
                .map { CountryListItem(section: 0, row: 0, code: $0) }
            self.countriesSection = .init(
                name: "All countries",
                items: allCountries,
                sectionIndex: 1
            )
            self.recommendedSection = .init(
                name: "Recommended",
                items: [.fastest] + recommendedCountries,
                sectionIndex: 0
            )
        }
    }

    enum Action: BindableAction {
        case selectItem(CountryListItem)
        case showCities(CountryListItem)
        case binding(BindingAction<State>)
        case confirmationDialog(PresentationAction<ConfirmationDialog>)

        @CasePathable
        enum ConfirmationDialog: Equatable {
            case connect(city: String)
        }
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .showCities(item):
                @Dependency(\.serverRepository) var repository
                let allCities = repository
                    .getGroups(filteredBy: [.isNotUnderMaintenance, .kind(.country(code: item.code))],
                               groupedBy: .cityName)
                    .enumerated()
                    .compactMap { index, group in
                        group.item(index: index, section: 1)
                    }

                state.confirmationDialog = ConfirmationDialogState(title: {
                    TextState("Select city to connect to")
                }, actions: {
                    for city in ["warszawa", "krakow"] {
                        ButtonState<Action.ConfirmationDialog>(action: .connect(city: city)) {
                            TextState(city)
                        }
                    }
                }, message: {
                    TextState("Select city to connect to")
                })
                return .none
            case let .confirmationDialog(.presented(.connect(city))):
                print("connect to \(city)")
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }
}

private extension ServerGroupInfo {
    func item(index: Int, section: Int) -> CountryListItem? {
        guard case let .country(code) = kind else { return nil }
        let row = Int(floor(Double(index) / Double(CountryListView.columnCount)))
        return CountryListItem(section: section, row: row, code: code)
    }
}
