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

import ComposableArchitecture
import Foundation
import CommonNetworking
import Domain
import Localization

struct HomeListSection: Equatable, Hashable {
    let name: String
    let items: [HomeListItem]
}

extension HomeListSection: Identifiable {
    var id: String { name }
}

struct HomeListItem: Identifiable, Equatable, Hashable {
    let id: String = UUID().uuidString

    let code: String
    let name: String
    let isConnected: Bool
}

@Reducer
struct CountryListFeature {

    @ObservableState
    struct State: Equatable {
        var sections: [HomeListSection] = []
        @Shared(.inMemory("connectionState")) var connectionState: ConnectFeature.ConnectionState?
    }

    enum Action {
        case onAppear
        case selectItem(HomeListItem)
        case updateList
        case connectionStateUpdated(ConnectFeature.ConnectionState?)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .connectionStateUpdated(let newState):
                return .run { send in
                    if case .connected = newState {
                        await send(.updateList)
                    }
                }
            case .onAppear:
                return .concatenate(
                    .run { [noSections = state.sections.isEmpty] send in
                        @Dependency(\.serverRepository) var repository
                        @Dependency(\.logicalsRefresher) var refresher
                        if repository.isEmpty || refresher.shouldRefreshLogicals() {
                            try await refresher.refreshLogicalsIfNeeded()
                            await send(.updateList)
                        } else if noSections {
                            await send(.updateList)
                        }
                    } catch: { error, action in
                        print("loadLogicals error: \(error)")
                        // TODO: error handling
                    },
                    .publisher { state.$connectionState.publisher.map(Action.connectionStateUpdated) }
                )
            case .updateList:
                @Dependency(\.serverRepository) var repository
                let allCountries = repository
                    .getGroups(filteredBy: [.isNotUnderMaintenance])
                    .compactMap { group in group.item(connectedCountryCode: state.connectionState?.connectedCountryCode) }

                // More info about recommended countries selection:
                // https://confluence.protontech.ch/pages/viewpage.action?pageId=128215858#Productmetricsforbusiness-Streaming
                let recommendedCountryCodes = ["US", "UK", "CA", "FR", "DE"]

                state.sections = [
                    HomeListSection(
                        name: "Recommended",
                        items: [fastest] + recommendedCountryCodes
                            .map { HomeListItem(
                                code: $0,
                                name: LocalizationUtility.default.countryName(forCode: $0) ?? "",
                                isConnected: isConnected(countryCode: $0, state: state) // TODO: Put real value when we have vpn connection working
                            ) }
                    ),
                    HomeListSection(
                        name: "All countries",
                        items: [fastest] + allCountries
                    ),
                ]
                return .none

            case .selectItem(let item):
                print(item)
                return .none
            }
        }
    }

    func isConnected(countryCode: String, state: State) -> Bool {
        guard case .connected(let code) = state.connectionState else {
            return false
        }
        return countryCode == code
    }

    private var fastest: HomeListItem {
        HomeListItem(
            code: "Fastest",
            name: "Fastest",
            isConnected: false // TODO: Put real value when we have vpn connection working
        )
    }
}

extension ConnectFeature.ConnectionState {
    var connectedCountryCode: String? {
        if case .connected(let code) = self {
            return code
        }
        return nil
    }
}

extension ServerGroupInfo {
    func item(connectedCountryCode: String?) -> HomeListItem? {
        switch kind {
        case .country(let code):
            return HomeListItem(
                code: code,
                name: LocalizationUtility.default.countryName(forCode: code) ?? "",
                isConnected: code == connectedCountryCode // TODO: Put real value when we have vpn connection working
            )
        default:
            return nil
        }
    }
}
