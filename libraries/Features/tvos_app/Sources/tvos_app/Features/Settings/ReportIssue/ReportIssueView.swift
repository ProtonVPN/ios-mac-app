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
import SwiftUI
import Theme

struct ReportIssueView: View {
    @Bindable var store: StoreOf<ReportIssueFeature>

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .themeSpacing32) {
                    textField("Email", text: $store.email)
                        .textInputAutocapitalization(.never)
                    textField("Username", text: $store.username)
                        .textInputAutocapitalization(.never)
                    textField("Which streaming service are you trying to use?", text: $store.whatAreYouTryingToDo, axis: .vertical)
                    textField("What went wrong? If you received an error message, let us know what it said.", text: $store.whatWentWrong, axis: .vertical)

                    Toggle("Send error logs", isOn: $store.sendErrorLogs)
                        .padding(.top, .themeSpacing8)

                    Text("A log is a type of file that shows us the actions you took that led to an error. We'll only ever use them to help our engineers fix bugs.")

                    Button("Send report") {
                        store.send(.sendReportTapped)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, .themeSpacing8)
                    .buttonStyle(TVButtonStyle())
                    .disabled(!store.canSendReport || store.isSending)
                    .padding(.horizontal, .themeSpacing12)
                }
                .frame(maxWidth: Dimensions.maxContentWidth, alignment: .leading)
                .padding(.horizontal, .themeSpacing8)
                .padding(.vertical, .themeSpacing48)
                .padding(.bottom, .themeSpacing32)
            }
            .disabled(store.isSending)

            if store.isSending {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                ProgressView("Sending report...")
                    .controlSize(.large)
                    .padding(.horizontal, .themeSpacing24)
                    .padding(.vertical, .themeSpacing16)
                    .background(Color(.background, .strong))
                    .clipShape(RoundedRectangle(cornerRadius: .themeRadius16))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .onAppear { store.send(.onAppear) }
        .onExitCommand { store.send(.onExitCommand) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private func textField(
        _ title: LocalizedStringResource,
        text: Binding<String>,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: .themeSpacing8) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)

            if axis == .vertical {
                TextField("", text: text, axis: axis)
                    .textFieldStyle(.plain)
                    .padding(.themeSpacing12)
                    .frame(maxWidth: .infinity, minHeight: Dimensions.multilineFieldMinHeight, alignment: .topLeading)
                    .submitLabel(.done)
            } else {
                TextField("", text: text, axis: axis)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .padding(.themeSpacing12)
                    .frame(maxWidth: .infinity, minHeight: Dimensions.singleLineFieldMinHeight, alignment: .leading)
                    .submitLabel(.done)
            }
        }
    }
}

private extension ReportIssueView {
    private enum Dimensions {
        static let maxContentWidth: CGFloat = 980
        static let multilineFieldMinHeight: CGFloat = 180
        static let singleLineFieldMinHeight: CGFloat = 56
    }
}

#if DEBUG
    #Preview {
        ReportIssueView(
            store: Store(
                initialState: .init(
                    email: "user@example.com",
                    username: "proton-user",
                    whatAreYouTryingToDo: "Open Netflix while connected to VPN",
                    whatWentWrong: "Playback fails with an error message after selecting a title.",
                    sendErrorLogs: true
                )
            ) {
                ReportIssueFeature()
            }
        )
        .frame(width: 1920, height: 1080)
        .background(Color(.background, .strong))
    }
#endif
