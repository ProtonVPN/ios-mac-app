//
//  Created on 23/02/2026 by Max Kupetskyi.
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
import ProtonCoreAPIClient
import VPNShared

@Reducer
struct ReportIssueFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.userDisplayName) var userDisplayName: String?
        @Presents var alert: AlertState<Action.Alert>?

        var email = ""
        var username = ""
        var whatAreYouTryingToDo = ""
        var whatWentWrong = ""
        var sendErrorLogs = true

        var isSending = false

        var canSendReport: Bool {
            !email.isEmpty && !whatAreYouTryingToDo.isEmpty && !whatWentWrong.isEmpty
        }
    }

    enum Action: BindableAction {
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case onAppear
        case onExitCommand
        case sendReportTapped
        case sendReportResponse(Result<Void, any Error>)

        @CasePathable
        enum Alert {
            case dismiss
        }
    }

    @Dependency(\.appInfo) private var appInfo
    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.fileManagerClient) private var fileManagerClient
    @Dependency(\.logContentProvider) private var logContentProvider
    @Dependency(\.reportIssueAPIClient) private var reportIssueAPIClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                let cleanedDisplayName = state.userDisplayName?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanedKeychainUsername = authKeychain.username?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedUsername = [cleanedDisplayName, cleanedKeychainUsername]
                    .compactMap { $0 }
                    .first(where: { !$0.isEmpty })
                    ?? ""
                if state.username.isEmpty {
                    state.username = resolvedUsername
                }
                if state.email.isEmpty {
                    state.email = ""
                }
                return .none
            case .onExitCommand:
                return .run { _ in
                    await dismiss()
                }
            case .sendReportTapped:
                guard !state.isSending, state.canSendReport else { return .none }
                state.isSending = true

                let form = state
                let appVersion = "\(appInfo.bundleShortVersion) (\(appInfo.bundleVersion))"
                return .run { send in
                    var temporaryLogFileURL: URL?
                    defer {
                        if let temporaryLogFileURL {
                            try? fileManagerClient.removeItem(at: temporaryLogFileURL)
                        }
                    }

                    var report = ReportBug(
                        os: "tvOS",
                        osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                        client: "App",
                        clientVersion: appVersion,
                        clientType: 2,
                        title: "Report from tvOS app",
                        description: """
                        What are you trying to do:
                        \(form.whatAreYouTryingToDo)
                        ---
                        What went wrong:
                        \(form.whatWentWrong)
                        ---
                        """,
                        username: form.username,
                        email: form.email,
                        country: "",
                        ISP: "",
                        plan: ""
                    )

                    if form.sendErrorLogs {
                        let logs = await logContentProvider.getLogData(for: .app).loadContent()
                        let fileURL = URL.temporaryDirectory.appendingPathComponent("ProtonVPN-tvOS-report.log")
                        try logs.write(to: fileURL, atomically: true, encoding: .utf8)
                        temporaryLogFileURL = fileURL
                        report.files = [fileURL]
                    }

                    try await reportIssueAPIClient.send(report)
                    await send(.sendReportResponse(.success(())))
                } catch: { error, send in
                    log.error("ReportIssueFeature failed to send bug report: \(error)")
                    await send(.sendReportResponse(.failure(error)))
                }
            case let .sendReportResponse(result):
                state.isSending = false
                switch result {
                case .success:
                    state.alert = AlertState {
                        TextState("Report sent")
                    } actions: {
                        ButtonState(action: .dismiss) {
                            TextState("OK")
                        }
                    }
                    state.whatAreYouTryingToDo = ""
                    state.whatWentWrong = ""
                case .failure:
                    state.alert = AlertState {
                        TextState("Failed to send report")
                    } actions: {
                        ButtonState(action: .dismiss) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("Please try again.")
                    }
                }
                return .none
            case .alert:
                return .none
            case .binding:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
