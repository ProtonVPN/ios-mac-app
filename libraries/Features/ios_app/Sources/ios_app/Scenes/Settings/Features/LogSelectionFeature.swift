//
//  Created on 12/02/2026 by Max Kupetskyi.
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
import Foundation
import Payments
import PCAP
import PMLogger
import SharedErgonomics
import Strings

@Reducer
struct LogSelectionFeature {
    @Reducer
    enum Destination {
        case logs(LogsViewFeature)
        case captureVPNSession(CaptureVPNSessionFeature)
    }

    @ObservableState
    struct State: Equatable {
        enum Row: Equatable {
            case logSource(LogSource)
            case pcap

            var title: String {
                switch self {
                case let .logSource(source):
                    source.title
                case .pcap:
                    Localizable.createTroubleshootingFile
                }
            }
        }

        @Presents var destination: Destination.State?
        var rows: [Row]
        var alertMessage: String?
        var shareLogsURL: URL?
        var title: String = "Logs"
        init(rows: [Row]) {
            self.rows = rows
        }

        init() {
            self.rows = LogSource
                .visibleAppSources
                .map(Row.logSource)
                .appending(.pcap)
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case rowTapped(State.Row)
    }

    @Dependency(\.fileManagerClient) private var fileManagerClient
    @Dependency(\.paymentsPlanServiceV2) private var paymentsPlanServiceV2

    var body: some ReducerOf<Self> {
        CombineReducers {
            BindingReducer()
            Reduce { state, action in
                switch action {
                case .binding:
                    return .none
                case let .rowTapped(row):
                    switch row {
                    case .pcap:
                        state.destination = .captureVPNSession(.init())
                        return .none
                    case let .logSource(source):
                        switch source {
                        case .transactionLog:
                            if let transactionLogURL = paymentsPlanServiceV2.generateTransactionLog() {
                                state.shareLogsURL = transactionLogURL
                            } else {
                                state.alertMessage = LogSelectionError.transactionLogNotFound.localizedDescription
                            }
                            return .none
                        default:
                            state.destination = .logs(.init(logSource: source))
                        }

                        return .none
                    }
                case let .destination(.presented(.logs(.shareFilePrepared(fileURL)))):
                    state.shareLogsURL = fileURL
                    return .none
                case .destination(.dismiss):
                    state.shareLogsURL = nil
                    return .none
                case .destination:
                    return .none
                }
            }
        }
        .ifLet(\.$destination, action: \.destination)
        // The shared file is temporary, so it is deleted whenever its URL goes away from the state.
        .onChange(of: \.shareLogsURL) { oldValue, _ in
            Reduce { _, _ in
                guard let oldValue else { return .none }
                do {
                    try fileManagerClient.removeItem(at: oldValue)
                } catch {
                    log.error("Failed to remove the shared log file", category: .app, metadata: ["error": "\(error)"])
                }
                return .none
            }
        }
    }
}

private enum LogSelectionError: LocalizedError {
    case transactionLogNotFound

    var errorDescription: String? {
        switch self {
        case .transactionLogNotFound:
            Localizable.transactionLogNotAvailable
        }
    }
}

// MARK: - Destination.State Equatable Conformance

extension LogSelectionFeature.Destination.State: Equatable {}
