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

@preconcurrency import Combine
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
        case startPortMappingObservation
        case portMapped(PortMappingPacketResponse)
        case portMappingFailed
        case stopPortMappingObservation
    }

    @Dependency(\.natPortMappingService) private var natPortMappingService
    @Dependency(\.date) private var date

    private var cancellables: [AnyCancellable] = []

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startPortMappingObservation:
                state = .loading
                return .publisher {
                    natPortMappingService.portMappingStream
                        .compactMap { portMapping in
                            guard let portMapping else { return nil }
                            return .portMapped(portMapping)
                        }
                        .replaceError(with: .portMappingFailed)
                }.cancellable(id: CancelID.portMappingStream, cancelInFlight: true)

            case let .portMapped(portMappingResponse):
                // check if the last value is not yet expired
                guard portMappingResponse.deadlineDate > date.now else { return .none }

                let externalPortNumber = portMappingResponse.mappedExternalPort
                let updateDate: Date = (state.externalPortNumber != externalPortNumber ? date.now : state.updateDate) ?? date.now
                state = .loaded(externalPortNumber: externalPortNumber, updateDate: updateDate, responseDate: date.now)
                return .none

            case .portMappingFailed:
                state = .error
                return .none

            case .stopPortMappingObservation:
                return .cancel(id: CancelID.portMappingStream)
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
