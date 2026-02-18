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
import PMLogger
import SharedErgonomics

@Reducer
struct LogSelectionFeature {
    @Reducer
    enum Destination {
        case logs(LogsViewFeature)
    }

    @ObservableState
    struct State: Equatable {
        enum Row: Equatable {
            case logSource(LogSource)
            case downloadAppleTVLogs

            var title: String {
                switch self {
                case let .logSource(source):
                    source.title
                case .downloadAppleTVLogs:
                    "Apple TV logs"
                }
            }
        }

        @Presents var destination: Destination.State?
        var rows: [Row] = LogSource.visibleAppSources.map(Row.logSource) + [.downloadAppleTVLogs]
        var alertMessage: String?
        var shareLogsURL: URL?
        var title: String = "Logs"
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case rowTapped(State.Row)
        case downloadResponse(Result<URL, Error>)
        case onDisappear
    }

    @Dependency(\.appleTVLogsDownloadClient) private var appleTVLogsDownloadClient
    @Dependency(\.fileManagerClient) private var fileManagerClient

    private enum CancelID {
        case appleTVLogsDownload
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case let .rowTapped(row):
                switch row {
                case let .logSource(source):
                    state.destination = .logs(.init(logSource: source))
                    return .none
                case .downloadAppleTVLogs:
                    return .run { send in
                        let fileURL = try await appleTVLogsDownloadClient.download()
                        await send(.downloadResponse(.success(fileURL)))
                    } catch: { error, send in
                        await send(.downloadResponse(.failure(error)))
                    }
                    .cancellable(id: CancelID.appleTVLogsDownload, cancelInFlight: true)
                }
            case let .downloadResponse(.success(fileURL)):
                state.shareLogsURL = fileURL
                return .none
            case let .downloadResponse(.failure(error)):
                state.alertMessage = error.localizedDescription
                return .none
            case let .destination(.presented(.logs(.shareFilePrepared(fileURL)))):
                state.shareLogsURL = fileURL
                return .none
            case .destination(.dismiss):
                cleanupFile(at: state.shareLogsURL)
                state.shareLogsURL = nil
                return .none
            case .destination:
                return .none
            case .onDisappear:
                cleanupFile(at: state.shareLogsURL)
                appleTVLogsDownloadClient.cancel()
                return .cancel(id: CancelID.appleTVLogsDownload)
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    private func cleanupFile(at url: URL?) {
        guard let url else { return }
        try? fileManagerClient.removeItem(at: url)
    }
}

// MARK: - Destination.State Equatable Conformance

extension LogSelectionFeature.Destination.State: Equatable {}
