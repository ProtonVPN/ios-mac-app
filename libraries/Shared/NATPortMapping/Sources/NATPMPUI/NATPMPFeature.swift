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
    public enum State: Equatable {
        case loading
        case loaded(externalPortNumber: UInt16, updateDate: Date, responseDate: Date)
        case error
    }

    public enum Action {
        case startPortMapping
        case portMapped(externalPortNumber: UInt16)
        case portMappingFailed
        case stopPortMapping
    }

    @Dependency(\.natPortMappingService) private var natPortMappingService
    @Dependency(\.date) private var date

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startPortMapping:
                state = .loading
                return .run { send in
                    for try await portMapping in natPortMappingService.portMappingStream {
                        await send(
                            .portMapped(externalPortNumber: portMapping.mappedExternalPort)
                        )
                    }
                } catch: { _, send in
                    await send(.portMappingFailed)
                }.cancellable(id: CancelID.portMappingStream, cancelInFlight: true)

            case let .portMapped(externalPortNumber):
                let updateDate: Date = (state.externalPortNumber != externalPortNumber ? date.now : state.updateDate) ?? date.now
                state = .loaded(externalPortNumber: externalPortNumber, updateDate: updateDate, responseDate: date.now)
                return .none

            case .portMappingFailed:
                state = .error
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

extension NATPMPFeature.State {
    var externalPortNumber: UInt16? {
        switch self {
        case let .loaded(portNumber, _, _):
            portNumber
        case .loading, .error:
            nil
        }
    }

    var updateDate: Date? {
        switch self {
        case let .loaded(_, date, _):
            date
        case .loading, .error:
            nil
        }
    }
}
