//
//  Created on 24/07/2025 by Max Kupetskyi.
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

import ComposableArchitecture
import Foundation
import NATPortMapping

@Reducer
public struct NATPMPFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        var isLoading: Bool = false
        var externalPortNumber: UInt16?
        var updateDate: Date?
    }

    public enum Action {
        case startPortMapping
        case portMapped(externalPortNumber: UInt16)
        case portMappingFailed
        case stopPortMapping
    }

    @Dependency(\.natPortMappingService) private var natPortMappingService
    @Dependency(\.date.now) private var now

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startPortMapping:
                state.isLoading = true
                return .merge(
                    .run { send in
                        for try await portMapping in natPortMappingService.portMappingStream {
                            await send(
                                .portMapped(externalPortNumber: portMapping.mappedExternalPort)
                            )
                        }
                    } catch: { _, send in
                        await send(.portMappingFailed)
                    }.cancellable(id: CancelID.portMappingStream)
                )

            case let .portMapped(externalPortNumber):
                state.isLoading = false
                if state.externalPortNumber != externalPortNumber {
                    state.externalPortNumber = externalPortNumber
                    // the date will be updated only on port change; otherwise it will be always < 2 min
                    state.updateDate = now
                }
                return .none

            case .portMappingFailed:
                state.isLoading = false
                state.externalPortNumber = nil
                state.updateDate = nil
                return .none

            case .stopPortMapping:
                return .merge(
                    .run { _ in
                        await natPortMappingService.cancelPortMapping()
                    },
                    .cancel(id: CancelID.portMappingStream)
                )
            }
        }
    }
}

private enum CancelID {
    case portMappingStream
}
