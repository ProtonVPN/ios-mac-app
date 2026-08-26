//
//  Created on 26/08/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import ComposableArchitecture
import VPNAppCore

@Reducer
public struct TelemetryConsentFeature {
    @ObservableState
    public struct State: Equatable {
        public var sharesUsageData = true
        public var sharesCrashReports = true

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case confirmButtonTapped
    }

    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .confirmButtonTapped:
                TelemetryOptIn.record(
                    sharesUsageData: state.sharesUsageData,
                    sharesCrashReports: state.sharesCrashReports
                )
                return .run { _ in await dismiss() }

            case .binding:
                return .none
            }
        }
    }
}
