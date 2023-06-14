//
//  Created on 09/06/2023.
//
//  Copyright (c) 2023 Proton AG
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

#if REDESIGN

struct InitialStateProvider {
    public let initialState: AppReducer.State
}

extension InitialStateProvider: DependencyKey {
    static let liveValue = InitialStateProvider(
        initialState: .init(home: .init(connections: [ .pinnedConnection,
                                                       .previousConnection,
                                                       .connectionSecureCoreFastest,
                                                       .connectionRegion],
                                        connectionStatus: .init(protectionState: .unprotected(country: "Poland", ip: "192.168.1.0"))))
    )
}

extension DependencyValues {
    var initialStateProvider: InitialStateProvider {
        get { self[InitialStateProvider.self] }
        set { self[InitialStateProvider.self] = newValue }
    }
}

#endif
