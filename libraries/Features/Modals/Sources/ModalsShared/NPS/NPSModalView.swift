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

/// Full-screen Net Promoter Score survey.
///
/// The modal opens with no score picked, which leaves the comment field hidden and the submit
/// button disabled. Picking a score reveals the optional comment field and enables submission.
public struct NPSModalView: View {
    @Bindable public var store: StoreOf<NPSModalFeature>

    @Environment(\.dismissWindow) private var dismissWindow

    /// Creates the survey view.
    /// - Parameter store: The store driving the survey.
    public init(store: StoreOf<NPSModalFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: .themeSpacing0) {
            #if os(iOS)
                NPSCloseButton { store.send(.closeTapped) }
            #endif
            Group {
                ScrollView { content }
                NPSSubmitButton(isEnabled: store.canSubmit) {
                    store.send(.submitTapped)
                    #if os(macOS)
                        dismissWindow()
                    #endif
                }
                .padding(.horizontal, .themeSpacing16)
                .padding(.bottom, .themeSpacing12)
            }
            .frame(maxWidth: Constants.maxHomeContentWidth)
        }
        .background(Color(.background))
        .animation(.default, value: store.isCommentFieldVisible)
    }

    var content: some View {
        VStack(spacing: .themeSpacing24) {
            VStack(spacing: .themeSpacing8) {
                Asset.npsSurvey.swiftUIImage
                NPSTitle()
            }

            NPSScoreSelector(selectedScore: store.score) { score in
                store.send(.scoreTapped(score))
            }

            if store.isCommentFieldVisible {
                NPSCommentField(comment: $store.comment)
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.bottom, .themeSpacing24)
    }
}

// MARK: - Subviews

/// The dismiss affordance in the top-leading corner.
private struct NPSCloseButton: View {
    let action: () -> Void

    private static let size: CGFloat = .themeSpacing8

    var body: some View {
        HStack(spacing: .themeSpacing0) {
            Button(action: action) {
                Theme.Asset.Icons.cross.swiftUIImage
                    .padding(.all, Self.size)
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
    var body: some View {
        Text(Localizable.npsModalTitle)
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
                    .frame(minHeight: Self.height)
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

/// The primary call to action, disabled until a score is picked.
private struct NPSSubmitButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(Localizable.npsModalSubmit)
        }
        .buttonStyle(ThemeButtonStyle(padding: .medium, style: .primary))
        .disabled(!isEnabled)
    }

    private var backgroundColor: Color {
        isEnabled
            ? Color(.background, .interactive)
            : Color(.background, [.interactive, .disabled])
    }
}

// MARK: - Typography

/// Typography used across the NPS survey, resolved per platform in a single place so the views
/// themselves stay free of conditional compilation.
extension AppTheme.Typography {
    #if os(iOS)
        static let npsTitle: Self = .headline
        static let npsScore: Self = .body2(emphasised: false)
        static let npsScaleHint: Self = .caption()
        static let npsCommentTitle: Self = .caption(emphasised: true)
        static let npsCommentBody: Self = .body1(.regular)
        static let npsCommentHint: Self = .caption()
        static let npsButton: Self = .body1(.semibold)
    #elseif os(macOS)
        static let npsTitle: Self = .title1(emphasised: true)
        static let npsScore: Self = .body()
        static let npsScaleHint: Self = .footnote()
        static let npsCommentTitle: Self = .callout(emphasised: true)
        static let npsCommentBody: Self = .body()
        static let npsCommentHint: Self = .footnote()
        static let npsButton: Self = .body(emphasised: true)
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
