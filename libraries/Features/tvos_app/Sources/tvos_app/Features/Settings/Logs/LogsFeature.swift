//
//  Created on 09/02/2026 by Max Kupetskyi.
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
struct LogsFeature {
    @ObservableState
    struct State: Equatable {
        let logSource: LogSource
        var logs: String = ""
        var isLoading = false
        var shareURL: URL?

        var title: String {
            logSource.title
        }
    }

    enum Action {
        case onAppear
        case onExitCommand
        case logsLoaded(String)
        case sharePrepared(URL)
        case prepareShareFile(String)
        case exportTapped
    }

    @Dependency(\.logContentProvider) private var logContentProvider
    @Dependency(\.dismiss) private var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading, state.logs.isEmpty else { return .none }
                state.isLoading = true
                let source = state.logSource
                return .run { send in
                    let content = logContentProvider.getLogData(for: source)
                    let logs = await content.loadContent()
                    await send(.logsLoaded(logs))
                }
            case let .logsLoaded(logs):
                state.isLoading = false
                state.logs = logs
                return .send(.prepareShareFile(logs))
            case .onExitCommand:
                if let url = state.shareURL {
                    try? FileManager.default.removeItem(at: url)
                }
                state.shareURL = nil
                return .run { _ in await dismiss() }

            // MARK: Export logs
            case let .prepareShareFile(logs):
                let source = state.logSource
                let filename = "\(state.title).log"
                return .run { send in
                    let content = logContentProvider.getLogData(for: source)
                    let logsContent = logs.isEmpty ? await content.loadContent() : logs
                    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                    try logsContent.write(to: fileURL, atomically: true, encoding: .utf8)
                    await send(.sharePrepared(fileURL))
                } catch: { error, _ in
                    log.error("LogsFeature failed to write share file: \(error)")
                }
            case let .sharePrepared(url):
                state.shareURL = url
                return .none
            case .exportTapped:
                if state.logs.isEmpty {
                    return .send(.prepareShareFile(""))
                }
                return .none
            }
        }
    }
}
