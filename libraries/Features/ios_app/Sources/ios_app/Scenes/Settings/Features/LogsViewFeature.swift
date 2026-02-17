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
struct LogsViewFeature {
    @ObservableState
    struct State: Equatable {
        let logSource: LogSource
        var logs = ""
        var pendingShareURL: URL?
        var temporaryShareFileURL: URL?

        var title: String { logSource.title }
    }

    enum Action {
        case onViewDidLoad
        case logsLoaded(String)
        case shareTapped
        case shareFilePrepared(URL)
    }

    @Dependency(\.logContentProvider) private var logContentProvider

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onViewDidLoad:
                let source = state.logSource
                return .run { send in
                    let content = logContentProvider.getLogData(for: source)
                    let logs = await content.loadContent()
                    await send(.logsLoaded(logs))
                }
            case let .logsLoaded(logs):
                state.logs = logs
                return .none
            case .shareTapped:
                let logs = state.logs
                let title = state.title
                return .run { send in
                    let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).log")
                    try logs.write(to: file, atomically: true, encoding: .utf8)
                    await send(.shareFilePrepared(file))
                } catch: { error, _ in
                    log.error("LogsViewFeature failed to prepare share file: \(error)")
                }
            case let .shareFilePrepared(file):
                cleanupFile(at: state.temporaryShareFileURL)
                state.temporaryShareFileURL = file
                state.pendingShareURL = file
                return .none
            }
        }
    }

    private func cleanupFile(at url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
