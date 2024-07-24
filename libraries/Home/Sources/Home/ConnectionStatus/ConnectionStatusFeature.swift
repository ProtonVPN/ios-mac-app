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

import Domain
import VPNAppCore

public struct ConnectionStatusFeature: Reducer {
    public struct State: Equatable {
        public var protectionState: ProtectionState

        public init(protectionState: ProtectionState) {
            self.protectionState = protectionState
        }
    }

    public enum Action: Equatable {
        case maskLocationTick

        case watchConnectionStatus
        case newConnectionStatus(VPNConnectionStatus)
    }

    public init() { }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .maskLocationTick:
                if case let .protecting(country, ip) = state.protectionState {
                    if let masked = partiallyMaskedLocation(country: country, ip: ip) {
                        state.protectionState = masked
                    }
                }
                return .run { action in
                    try await Task.sleep(nanoseconds: 50_000_000)
                    await action(.maskLocationTick)
                }.cancellable(id: MaskLocation.task, cancelInFlight: true)

            case .watchConnectionStatus:
                return .run { send in
                    @Dependency(\.vpnConnectionStatusPublisher) var vpnConnectionStatusPublisher
                    
                    if #available(macOS 12.0, *) {
//                        for await vpnStatus in vpnConnectionStatusPublisher().values {
//                            await send(.newConnectionStatus(vpnStatus), animation: .default)
//                        }
                    } else {
                        assertionFailure("Use target at least macOS 12.0")
                    }
                }

            case .newConnectionStatus(let status):
                state.protectionState = status.protectionState
                guard case .protecting = status.protectionState else {
                    return .cancel(id: MaskLocation.task)
                }
                return .send(.maskLocationTick)
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
