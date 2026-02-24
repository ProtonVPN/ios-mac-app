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
        ScrollView {
            VStack(alignment: .leading, spacing: .themeSpacing32) {
                textField("Email", text: $store.email)
                    .textInputAutocapitalization(.never)
                textField("Username", text: $store.username)
                    .textInputAutocapitalization(.never)
                textField("What are you trying to do", text: $store.whatAreYouTryingToDo, axis: .vertical)
                textField("What went wrong", text: $store.whatWentWrong, axis: .vertical)

                Toggle("Send error logs", isOn: $store.sendErrorLogs)
                    .padding(.top, .themeSpacing8)

                Button("Send report") {
                    store.send(.sendReportTapped)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, .themeSpacing8)
                .buttonStyle(.automatic)
                .disabled(!store.canSendReport || store.isSending)

                if store.isSending {
                    ProgressView("Sending report...")
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(.horizontal, .themeSpacing8)
            .padding(.vertical, .themeSpacing48)
            .padding(.bottom, .themeSpacing32)
        }
        .onAppear { store.send(.onAppear) }
        .onExitCommand { store.send(.onExitCommand) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private func textField(_ title: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: .themeSpacing8) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)

            if axis == .vertical {
                TextField("", text: text, axis: axis)
                    .textFieldStyle(.plain)
                    .lineLimit(6 ... 12)
                    .padding(.themeSpacing12)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                    .submitLabel(.done)
            } else {
                TextField("", text: text, axis: axis)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .padding(.themeSpacing12)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .submitLabel(.done)
            }
        }
    }
}

private struct ReportIssueButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .bold()
            .padding(.horizontal, .themeSpacing32)
            .padding(.vertical, .themeSpacing24)
            .background(isFocused ? Color(.background, .selected) : Color(.background, .weak))
            .foregroundStyle(isFocused ? Color(.text, .inverted) : Color(.text))
            .cornerRadius(.themeRadius16)
    }
}
