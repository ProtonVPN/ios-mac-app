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

@Reducer
struct LogSelectionFeature {
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

        var rows: [Row] = LogSource.visibleAppSources.map(Row.logSource) + [.downloadAppleTVLogs]
        var pendingShareURL: URL?
        var pendingLogSource: LogSource?
        var alertMessage: String?
        var title: String = "Logs"
    }

    enum Action {
        case rowTapped(State.Row)
        case downloadResponse(Result<URL, Error>)
        case clearPendingShareURL
        case clearPendingLogSource
        case clearAlert
        case onDisappear
    }

    @Dependency(\.appleTVLogsDownloadClient) private var appleTVLogsDownloadClient

    private enum CancelID {
        case appleTVLogsDownload
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .rowTapped(row):
                switch row {
                case let .logSource(source):
                    state.pendingLogSource = source
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
                state.pendingShareURL = fileURL
                return .none
            case let .downloadResponse(.failure(error)):
                state.alertMessage = error.localizedDescription
                return .none
            case .clearPendingShareURL:
                state.pendingShareURL = nil
                return .none
            case .clearPendingLogSource:
                state.pendingLogSource = nil
                return .none
            case .clearAlert:
                state.alertMessage = nil
                return .none
            case .onDisappear:
                appleTVLogsDownloadClient.cancel()
                return .cancel(id: CancelID.appleTVLogsDownload)
            }
        }
    }
}
