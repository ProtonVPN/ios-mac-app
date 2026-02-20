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
import CountriesShared
import Strings
import SwiftUI
import Theme

struct DiscourageSecureCoreView: View {
    var store: StoreOf<DiscourageSecureCoreFeature>
    @Environment(\.dismiss) var dismiss

    var body: some View {
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
        Image("SecureCoreDiscourage", bundle: CountriesResources.bundle)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
    }

    private var titleSection: some View {
        VStack(spacing: .themeSpacing8) {
            Text(Localizable.modalsDiscourageSecureCoreTitle)
                .themeFont(.headline)
                .foregroundStyle(Color(.text))
                .multilineTextAlignment(.center)

            Text(Localizable.modalsDiscourageSecureCoreSubtitle)
                .themeFont(.body1(.regular))
                .foregroundStyle(Color(.text, .weak))
                .multilineTextAlignment(.center)
        }
    }

    private var learnMoreButton: some View {
        Button {
            store.send(.learnMoreTapped)
        } label: {
            Text(Localizable.modalsCommonLearnMore)
                .themeFont(.body1(.regular))
                .foregroundStyle(Color(.text, .interactive))
        }
    }

    private var dontShowAgainToggle: some View {
        HStack {
            Text(Localizable.modalsDiscourageSecureCoreDontShow)
                .themeFont(.body2(emphasised: false))
                .foregroundStyle(Color(.text))

            Spacer()

            Toggle(isOn: Binding(
                get: { store.dontShowAgain },
                set: { _ in store.send(.toggleDontShowAgain) }
            )) {
                Text("")
            }
            .labelsHidden()
            .foregroundStyle(Color(.background, .interactive))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: .themeSpacing12) {
            Button {
                store.send(.activateTapped)
            } label: {
                Text(Localizable.modalsDiscourageSecureCoreActivate)
                    .themeFont(.body1(.regular))
                    .foregroundStyle(Color(.text))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .themeSpacing12)
                    .background(Color(.background, .interactive))
                    .clipShape(RoundedRectangle(cornerRadius: .themeRadius8))
            }

            Button {
                dismiss()
            } label: {
                Text(Localizable.modalsCommonCancel)
                    .themeFont(.body1(.regular))
                    .foregroundStyle(Color(.text, .interactive))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .themeSpacing12)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DiscourageSecureCoreView(
        store: Store(initialState: DiscourageSecureCoreFeature.State()) {
            DiscourageSecureCoreFeature()
        }
    )
    .preferredColorScheme(.dark)
}

// MARK: - Bundle Token

private final class BundleToken {}
