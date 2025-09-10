//
//  Created on 09/09/2025 by adam.
//
//  Copyright (c) 2025 Proton AG
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

import SwiftUI

import Strings
import Theme

import Domain
import Perception

private typealias ButtonAction = () -> Void
private typealias OnTwoFactorButtonAction = (String) -> Void

private struct SwiftUITwoFactorView: NSViewRepresentable {
    let onTwoFactorButtonAction: OnTwoFactorButtonAction
    let onBackAction: ButtonAction
    let onKeychainHelpAction: ButtonAction

    func makeNSView(context: Context) -> TwoFactorView {
        var nibObjects: NSArray?
        let loaded = Bundle.main.loadNibNamed("TwoFactorView", owner: nil, topLevelObjects: &nibObjects)
        guard loaded, let view = nibObjects?.first(where: { $0 is TwoFactorView }) as? TwoFactorView else {
            return TwoFactorView(frame: .zero)
        }
        view.delegate = context.coordinator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateNSView(_: TwoFactorView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTwoFactorButtonAction: onTwoFactorButtonAction,
            onBackAction: onBackAction,
            onKeychainHelpAction: onKeychainHelpAction
        )
    }

    final class Coordinator: NSObject, TwoFactorDelegate {
        let onTwoFactorButtonAction: OnTwoFactorButtonAction
        let onBackAction: ButtonAction
        let onKeychainHelpAction: ButtonAction

        init(
            onTwoFactorButtonAction: @escaping OnTwoFactorButtonAction,
            onBackAction: @escaping ButtonAction,
            onKeychainHelpAction: @escaping ButtonAction
        ) {
            self.onTwoFactorButtonAction = onTwoFactorButtonAction
            self.onBackAction = onBackAction
            self.onKeychainHelpAction = onKeychainHelpAction
        }

        func twoFactorButtonAction(code: String) {
            onTwoFactorButtonAction(code)
        }

        func backAction() {
            onBackAction()
        }

        func keychainHelpAction() {
            onKeychainHelpAction()
        }
    }
}

@MainActor
struct HardwareKeyTwoFactorView: View {
    let onAuthenticateAction: () -> Void

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                Image("login-hardware-key")
                    .resizable()
                    .frame(width: 292, height: 150)
                Text("Insert the U2F or FIDO key linked to your Proton Account. Learn more") // TODO: Learn more Link
            }

            Button(Localizable.authenticate) {
                onAuthenticateAction()
            }
            .buttonStyle(ThemeButtonStyle(padding: .small, style: .primary))
        }
        .padding()
    }
}

final class AnyTwoFactorView: NSHostingView<AnyTwoFactorSwiftUIView> {
    let viewModel: AnyTwoFactorViewModel

    init(viewModel: AnyTwoFactorViewModel) {
        self.viewModel = viewModel
        super.init(rootView: AnyTwoFactorSwiftUIView(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor @preconcurrency
    dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented.")
    }

    @MainActor @preconcurrency
    required init(rootView _: AnyTwoFactorSwiftUIView) {
        fatalError("init(rootView:) should not be used. Use the init(viewModel:) instead.")
    }
}

@MainActor
struct AnyTwoFactorSwiftUIView: View {
    enum TwoFactorKind: Int, CaseIterable {
        case totp
        case hardwareKey
    }

    @Perception.Bindable var viewModel: AnyTwoFactorViewModel

    // the default value will be the one selected when view appears
    @State private var twoFactorKind: TwoFactorKind = .hardwareKey

    var body: some View {
        WithPerceptionTracking {
            VStack {
                Picker("", selection: $twoFactorKind) {
                    ForEach(TwoFactorKind.allCases, id: \.self) { kind in
                        Text(kind.pickerMenuTitle)
                            .tag(kind.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch twoFactorKind {
                case .totp:
                    SwiftUITwoFactorView { code in
                        viewModel.provide2FACode(code: code)
                    } onBackAction: {
                        viewModel.backAction()
                    } onKeychainHelpAction: {
                        viewModel.keychainHelpAction()
                    }
                case .hardwareKey:
                    HardwareKeyTwoFactorView {
                        viewModel.presentAuthController()
                    }
                    .task {
                        for await event in viewModel.stream {
                            viewModel.handleNewAnyTwoFactorViewModelEvent(event)
                        }
                    }
                }
            }
            .alert(isPresented: $viewModel.showErrorAlert, error: viewModel.twoFactorError) { _ in
                Button(Localizable.ok) {}
            } message: { error in
                Text(error.recoverySuggestion ?? Localizable.genericErrorTitle)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private extension AnyTwoFactorSwiftUIView.TwoFactorKind {
    var pickerMenuTitle: String {
        switch self {
        case .totp:
            "Authenticator app"
        case .hardwareKey:
            "Security key"
        }
    }
}
