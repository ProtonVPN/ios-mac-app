//
//  Created on 22/01/2026 by Max Kupetskyi.
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

public struct DiscourageSecureCoreView: View {
    public let store: StoreOf<DiscourageSecureCoreFeature>
    public let dismissOnAction: Bool
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<DiscourageSecureCoreFeature>, dismissOnAction: Bool = true) {
        self.store = store
        self.dismissOnAction = dismissOnAction
    }

    public var body: some View {
        VStack(spacing: .themeSpacing0) {
            ScrollView {
                VStack(spacing: .themeSpacing0) {
                    artImage
                        .padding(.bottom, .themeSpacing24)

                    titleSection
                        .padding(.bottom, .themeSpacing16)

                    learnMoreButton
                        .padding(.bottom, .themeSpacing24)

                    dontShowAgainToggle
                }
                .padding(.horizontal, .themeSpacing24)
                .padding(.top, .themeSpacing32)
            }

            actionButtons
                .padding(.horizontal, .themeSpacing24)
                .padding(.vertical, .themeSpacing24)
        }
        .background(Color(.background))
    }

    // MARK: - Subviews

    private var artImage: some View {
        Asset.secureCoreDiscourage.swiftUIImage
        #if os(iOS)
            .resizable()
            .aspectRatio(contentMode: .fit)
        #endif
            .frame(maxWidth: .infinity)
    }

    private var titleSection: some View {
        VStack(spacing: .themeSpacing8) {
            Text(Localizable.modalsDiscourageSecureCoreTitle)
            #if os(iOS)
                .themeFont(.headline)
                .foregroundStyle(Color(.text))
            #elseif os(macOS)
                .themeFont(.title1())
                .foregroundStyle(Color(.white))
            #endif
                .multilineTextAlignment(.center)

            Text(Localizable.modalsDiscourageSecureCoreSubtitle)
            #if os(iOS)
                .themeFont(.body1(.regular))
                .foregroundStyle(Color(.text, .weak))
            #elseif os(macOS)
                .themeFont(.title2())
                .foregroundStyle(Color(.white))
            #endif
                .multilineTextAlignment(.center)
        }
    }

    private var learnMoreButton: some View {
        Button {
            store.send(.learnMoreTapped)
        } label: {
            Text(Localizable.modalsCommonLearnMore)
            #if os(iOS)
                .themeFont(.body1(.regular))
            #elseif os(macOS)
                .themeFont(.callout())
            #endif
                .foregroundStyle(Color(.text, .interactive))
        }
        .buttonStyle(.plain)
    }

    private var dontShowAgainToggle: some View {
        HStack {
            Spacer()

            Toggle(isOn: Binding(
                get: { store.dontShowAgain },
                set: { _ in store.send(.toggleDontShowAgain) }
            )) {
                HStack {
                    Text(Localizable.modalsDiscourageSecureCoreDontShow)
                    #if os(iOS)
                        .themeFont(.body2(emphasised: false))
                        .foregroundStyle(Color(.text))
                    #endif

                    #if os(iOS)
                        Spacer()
                    #endif
                }
            }
            #if os(iOS)
            .tint(Color(.text, .interactive))
            #endif
            #if os(macOS)
            .fixedSize()
            #endif

            Spacer()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: .themeSpacing12) {
            DiscourageSecureCoreActivateButton {
                store.send(.activateTapped)
                if dismissOnAction {
                    dismiss()
                }
            }

            Button {
                store.send(.cancelTapped)
                if dismissOnAction {
                    dismiss()
                }
            } label: {
                Text(Localizable.modalsCommonCancel)
                #if os(iOS)
                    .themeFont(.body1(.regular))
                    .frame(maxWidth: .infinity)
                #elseif os(macOS)
                    .themeFont(.title3())
                #endif
                    .foregroundStyle(Color(.text, .interactive))
                    .padding(.vertical, .themeSpacing12)
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
    #Preview {
        DiscourageSecureCoreView(
            store: Store(initialState: DiscourageSecureCoreFeature.State()) {
                DiscourageSecureCoreFeature()
            }
        )
        .preferredColorScheme(.dark)
    }
#endif
