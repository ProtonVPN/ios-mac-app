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

public struct ConnectionStatusFeature: Reducer {
    public struct State: Equatable {
        public var protectionState: ProtectionState

        public init(protectionState: ProtectionState) {
            self.protectionState = protectionState
        }
    }

    public enum Action: Equatable {
        case update(ProtectionState)
    }

    public init() { }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .update(protectionState):
                state.protectionState = protectionState
                if case .protected = protectionState {
                    return .cancel(id: MaskLocation.task)
                }
                return .run { action in
                    try await Task.sleep(nanoseconds: 50_000_000)
                    if case let .protecting(country, ip) = protectionState {
                        if let masked = partiallyMaskedLocation(country: country, ip: ip) {
                            await action.send(.update(masked))
                        }
                    }
                }.cancellable(id: MaskLocation.task)
            }
        }
    }

    enum MaskLocation {
        case task
    }

    func partiallyMaskedLocation(country: String, ip: String) -> ProtectionState? {
        let replacedCountry = country.partiallyMasked()
        let replacedIP = ip.partiallyMasked()
        if let replacedIP, let replacedCountry {
            if Bool.random() {
                return .protecting(country: replacedCountry, ip: ip)
            } else {
                return .protecting(country: country, ip: replacedIP)
            }
        } else if let replacedIP {
            return .protecting(country: country, ip: replacedIP)
        } else if let replacedCountry {
            return .protecting(country: replacedCountry, ip: ip)
        }
        return nil
    }
}
