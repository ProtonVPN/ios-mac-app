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

import CommonNetworking
import ComposableArchitecture
import Foundation
import PMLogger
import ProtonCoreAPIClient
import SharedErgonomics
import VPNShared

@Reducer
struct ReportIssueFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.userDisplayName) var userDisplayName: String?
        @Shared(.userEmail) var userEmail: String?
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
        case sendReportResponse(Result<ReportsBugResponse, any Error>)

        @CasePathable
        enum Alert {
            case dismiss
        }
    }

    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.fileManagerClient) private var fileManagerClient
    @Dependency(\.reportIssueAPIClient) private var reportIssueAPIClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                let cleanedDisplayName = state.userDisplayName?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanedEmail = state.userEmail?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if state.username.isEmpty {
                    state.username = cleanedDisplayName ?? ""
                }
                if state.email.isEmpty {
                    state.email = cleanedEmail ?? ""
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
                return .run { send in
                    let (report, attachedLogFileURL) = try await ReportIssueForm(
                        username: form.username,
                        email: form.email,
                        whatAreYouTryingToDo: form.whatAreYouTryingToDo,
                        whatWentWrong: form.whatWentWrong,
                        shouldSendErrorLogs: form.sendErrorLogs
                    ).asBugReport()
                    defer {
                        if let attachedLogFileURL {
                            try? fileManagerClient.removeItem(at: attachedLogFileURL)
                        }
                    }

                    await send(.sendReportResponse(Result { try await reportIssueAPIClient.send(report) }))
                } catch: { error, _ in
                    log.error("ReportIssueFeature failed to send bug report: \(error)")
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
                case let .failure(error):
                    log.error("ReportIssueFeature failed to send bug report: \(error)")
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
