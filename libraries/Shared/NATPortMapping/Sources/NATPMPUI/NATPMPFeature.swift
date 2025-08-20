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
        case loading(lastExternalPortNumber: UInt16?, lastUsedUpdateDate: Date?)
        case loaded(externalPortNumber: UInt16, updateDate: Date)
        case error
    }

    public enum Action {
        case startPortMappingObservation
        case portMapped(PortMappingPacketResponse)
        case portMappingFailed
        case portMappingReceivedNil
        case stopPortMappingObservation
    }

    @Dependency(\.natPortMappingService) private var natPortMappingService
    @Dependency(\.date) private var date

    private var cancellables: [AnyCancellable] = []

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startPortMappingObservation:
                state = .loading(lastExternalPortNumber: state.externalPortNumber, lastUsedUpdateDate: state.updateDate)
                return .publisher {
                    natPortMappingService.portMappingStream
                        .removeDuplicates(by: { prevResult, nextResult in
                            switch (prevResult, nextResult) {
                            case let (.success(prevPortMapping), .success(nextPortMapping)):
                                // consume next value only if mapped ports are not the same
                                prevPortMapping?.mappedExternalPort == nextPortMapping?.mappedExternalPort
                            case (.success, .failure), (.failure, .success):
                                false
                            case (.failure, .failure):
                                // we don't differentiate errors; thus all subsequent errors are "equal"
                                true
                            }
                        })
                        .compactMap { portMappingResult in
                            switch portMappingResult {
                            case let .success(portMapping):
                                guard let portMapping else { return .portMappingReceivedNil }
                                return .portMapped(portMapping)
                            case .failure:
                                return .portMappingFailed
                            }
                        }
                        .replaceError(with: .portMappingFailed)
                }.cancellable(id: CancelID.portMappingStream, cancelInFlight: true)

            case let .portMapped(portMappingResponse):
                // check if the last value is not yet expired
                guard portMappingResponse.deadlineDate > date.now else { return .none }
                let updateDate: Date = if state.externalPortNumber == portMappingResponse.mappedExternalPort, let savedDate = state.updateDate {
                    savedDate
                } else {
                    portMappingResponse.createDate
                }
                state = .loaded(externalPortNumber: portMappingResponse.mappedExternalPort, updateDate: updateDate)
                return .none

            // if nat pmp service returned `nil`
            case .portMappingReceivedNil:
                state = .loading(lastExternalPortNumber: nil, lastUsedUpdateDate: nil)
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
        case let .loaded(portNumber, _):
            portNumber
        case let .loading(lastUsedExternalPortNumber, _):
            lastUsedExternalPortNumber
        case .error:
            nil
        }
    }

    var updateDate: Date? {
        switch self {
        case let .loaded(_, date):
            date
        case let .loading(_, lastUsedUpdateDate):
            lastUsedUpdateDate
        case .error:
            nil
        }
    }
}
