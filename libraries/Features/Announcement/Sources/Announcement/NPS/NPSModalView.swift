//
//  Created on 2026-08-26 by Pawel Jurczyk.
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
import Strings
import SwiftUI
import Theme

public struct NPSModalView: View {
    @Bindable public var store: StoreOf<NPSModalFeature>

    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<NPSModalFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: .themeSpacing0) {
            #if os(iOS)
                NPSCloseButton {
                    store.send(.closeTapped)
                    dismiss()
                }
            #endif
            Group {
                content
                Spacer()
                if store.didSubmit {
                    NPSSubmitButton(isEnabled: true, text: Localizable.done) {
                        #if os(macOS)
                            dismissWindow()
                        #else
                            dismiss()
                        #endif
                    }
                } else {
                    NPSSubmitButton(isEnabled: store.canSubmit, text: Localizable.npsModalSubmit) {
                        store.send(.submitTapped)
                    }
                }
            }
        }
        .background(Color(.background))
        .interactiveDismissDisabled()
    }

    var content: some View {
        VStack(spacing: .themeSpacing24) {
            if store.didSubmit {
                Asset.npsSurveySuccess.swiftUIImage
                NPSTitle(text: Localizable.npsModalTitleThanksForSharing)
                Text(Localizable.npsModalTitleThanksSubtitle)
                    .themeFont(.npsSubtitle)
                    .foregroundStyle(Color(.text, .weak))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Asset.npsSurvey.swiftUIImage
                NPSTitle(text: Localizable.npsModalTitle)
            }

            if !store.didSubmit {
                NPSScoreSelector(selectedScore: store.score) { score in
                    store.send(.scoreTapped(score))
                }

                if store.isCommentFieldVisible {
                    NPSCommentField(comment: $store.comment)
                }
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.bottom, .themeSpacing24)
    }
}

// MARK: - Subviews

private struct NPSCloseButton: View {
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Theme.Asset.Icons.cross.swiftUIImage
                    .padding(.themeSpacing8)
                    .foregroundStyle(Color(.icon))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Localizable.close)

            Spacer()
        }
        .padding(.horizontal, .themeSpacing8)
        .padding(.vertical, .themeSpacing2)
    }
}

private struct NPSTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .themeFont(.npsTitle)
            .foregroundStyle(Color(.text))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct NPSCommentField: View {
    @Binding var comment: String

    private static let height: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing4) {
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                Text(Localizable.npsModalCommentTitle)
                    .themeFont(.npsCommentTitle)
                    .foregroundStyle(Color(.text))

                TextEditor(text: $comment)
                    .onChange(of: comment) {
                        comment = String(comment.prefix(NPSModalFeature.maxCommentCharLength))
                    }
                    .font(.themeFont(.npsCommentBody))
                    .foregroundStyle(Color(.text))
                    .scrollContentBackground(.hidden)
                    .frame(height: Self.height)
                    .background(Color(.background, .weak))
                    .clipShape(.rect(cornerRadius: .themeRadius8))
                    .accessibilityLabel(Localizable.npsModalCommentTitle)
            }
            Text(Localizable.npsModalCommentOptional)
                .themeFont(.npsCommentHint)
                .foregroundStyle(Color(.text, .weak))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NPSSubmitButton: View {
    let isEnabled: Bool
    let text: String
    let action: () -> Void

    var body: some View {
        Button(text, action: action)
            .buttonStyle(ThemeButtonStyle(padding: .medium, style: .primary))
            .disabled(!isEnabled)
            .padding(.horizontal, .themeSpacing16)
            .padding(.bottom, .themeSpacing12)
    }
}

// MARK: - Typography

extension AppTheme.Typography {
    #if os(iOS)
        static let npsTitle: Self = .headline
        static let npsSubtitle: Self = .body1(.regular)
        static let npsScore: Self = .body2(emphasised: false)
        static let npsScaleHint: Self = .caption()
        static let npsCommentTitle: Self = .caption(emphasised: true)
        static let npsCommentBody: Self = .body1(.regular)
        static let npsCommentHint: Self = .caption()
    #elseif os(macOS)
        static let npsTitle: Self = .title2(emphasised: true)
        static let npsSubtitle: Self = .body(emphasised: false)
        static let npsScore: Self = .body(emphasised: false)
        static let npsScaleHint: Self = .callout(emphasised: false)
        static let npsCommentTitle: Self = .headline(emphasised: true)
        static let npsCommentBody: Self = .body(emphasised: false)
        static let npsCommentHint: Self = .callout(emphasised: false)
    #endif
}

// MARK: - Previews

#Preview("Modal start") {
    NPSModalView(
        store: Store(initialState: NPSModalFeature.State()) {
            NPSModalFeature()
        }
    )
    .environment(\.colorScheme, .dark)
}

#Preview("Selected") {
    NPSModalView(
        store: Store(initialState: NPSModalFeature.State(score: 7)) {
            NPSModalFeature()
        }
    )
    .environment(\.colorScheme, .dark)
}
