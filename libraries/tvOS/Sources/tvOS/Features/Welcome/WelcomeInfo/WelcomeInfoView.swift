//
//  Created on 23/04/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import SwiftUI
import ComposableArchitecture

struct WelcomeInfoView: View {

    var store: StoreOf<WelcomeInfoFeature>

    var body: some View {
        switch store.state {
        case .freeUpsellAlternative:
            UpsellAlternativeView(model: store.state.model)
        default:
            view(model: store.state.model)
        }
    }

    private func view(model: WelcomeInfoFeature.State.Model) -> some View {
        HStack {
            VStack(spacing: .themeSpacing32) {
                HStack(spacing: 0) {
                    Text(model.title)
                        .font(.title)
                        .bold()
                    Spacer(minLength: 0)
                }
                HStack {
                    Text(model.subtitle)
                        .font(.title3)
                        .foregroundStyle(Color(.text, .weak)) +
                    Text(verbatim: model.displayURL ?? "")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(Color(.text, .interactive))
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: Constants.maxPreferredContentViewWidth)
            QRCodeView(string: model.url)
        }
        .background(Image(.backgroundStage))
    }
}

struct UpsellAlternativeView: View {

    static let contentViewWidth: CGFloat = 928

    @Environment(\.dismiss) var dismiss

    var model: WelcomeInfoFeature.State.Model

    @FocusState var focusState: Bool

    var body: some View {
        VStack(alignment: .center, spacing: .themeSpacing32) {
            Text(model.title)
                .font(.title)
                .bold()
            Button {
                dismiss()
            } label: {
                Text("Got it", comment: "Button title when user was presented an informative screen")
            }
            .focused($focusState, equals: true)
            .buttonStyle(TVButtonStyle())
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: Self.contentViewWidth)
        .background(Image(.backgroundStage))
    }
}
