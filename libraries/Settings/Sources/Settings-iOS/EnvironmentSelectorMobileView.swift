//
//  Created on 29.11.2024.
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

import Foundation
import SwiftUI

import ComposableArchitecture

import Settings
import Theme

public struct EnvironmentSelectorMobileView: View {
    @Binding public var store: StoreOf<EnvironmentSelectorFeature>

    @ViewBuilder
    var selectedEnvironmentSection: some View {
        Section(header: Text("Selected Environment").font(.headline)) {
            Text(store.apiEndpoint)
                .themeFont(.body1(.regular))
                .padding(.top, .themeSpacing2)

            Button("Use and continue") {
                store.send(.useAndContinueButtonTapped)
            }
            .buttonStyle(EnvironmentSelectorButtonStyle.active)
            .padding(.vertical, .themeSpacing6)
        }
    }

    var changeEnvironmentCaption: Text {
        let (style, text) = store.state.environmentsCaption
        return Text(text)
            .themeFont(.caption())
            .styled(style)
    }

    @ViewBuilder
    var changeEnvironmentSection: some View {
        Section(header: Text("Change Environment").font(.headline)) {
            TextField("Environment URL", text: $store.newApiEndpointURLString)
                .accessibilityIdentifier("customEnvironmentTextField") // Needed for automation
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.themeSpacing4)
                .font()
                .border(Color(.border, .weak))
                .clipShape(.rect(cornerRadius: .themeRadius4))
                .padding(.horizontal, .themeSpacing12)

            HStack {
                Text("Atlas:")
                    .styled(.weak)
                    .font(.body1(.regular))
                    .padding(.leading, .themeSpacing12)

                TextField("Atlas Secret", text: $store.atlasSecret)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.themeSpacing4)
                    .font()
                    .border(Color(.border, .weak))
                    .clipShape(.rect(cornerRadius: .themeRadius4))
                    .padding(.horizontal, .themeSpacing12)

                if store.state.fetchingAtlasSecret {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.trailing, .themeSpacing12)
                }

                Button("Fetch...") {
                    store.send(.fetchAtlasSecretButtonTapped)
                }
                .buttonStyle(EnvironmentSelectorButtonStyle.inActive)
                .padding(.trailing, .themeSpacing12)
            }

            changeEnvironmentCaption
        }
    }

    @ViewBuilder
    var featureOverridesSection: some View {
        Section(header: Text("Feature Overrides").font(.headline)) {
            List {
                ForEach($store.overrides, id: \.id) { $featureOverride in
                    HStack {
                        TextField("Override \(featureOverride.index + 1)", text: $featureOverride.name)
                            .autocorrectionDisabled()

                        Spacer()
                        Image(systemName: featureOverride.value ? "checkmark.square.fill" : "clear.fill")
                            .styled(featureOverride.value ? .success : .danger)
                            .onTapGesture {
                                store.send(.toggle(id: featureOverride.id))
                            }
                    }
                }
                .onDelete(perform: { indexSet in
                    store.send(.overridesRemoved(indexSet))
                })
            }
            .scrollContentBackground(.hidden)
            .availabilitySafeContentMargins(.top, .init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }

    }

    @ViewBuilder
    var bottomButtonsSection: some View {
        Button("Change and kill the app") {
            store.send(.changeAndKillAppButtonTapped)
        }
        .buttonStyle(EnvironmentSelectorButtonStyle.active)
        .padding(.bottom, .themeSpacing4)

        Button("Reset to production and kill the app") {
            store.send(.resetAndKillAppButtonTapped)
        }
        .buttonStyle(EnvironmentSelectorButtonStyle.active)
    }

    public var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                VStack(alignment: .center) {
                    selectedEnvironmentSection
                        .padding(.vertical, .themeSpacing6)
                    changeEnvironmentSection
                        .padding(.bottom, .themeSpacing6)
                    featureOverridesSection
                        .padding(.bottom, .themeSpacing6)
                    bottomButtonsSection
                }
            }
            .padding(.top, .themeSpacing16)
            .alert($store.scope(state: \.alert, action: \.alert))
            .frame(maxWidth: Theme.Constants.readableContentWidth)
        }
    }

    init(store: StoreOf<EnvironmentSelectorFeature>) {
        self._store = .constant(store)
    }

    public init(continueHandler: @escaping () -> Void) {
        self.init(store: .init(initialState: EnvironmentSelectorFeature.State(), reducer: {
            EnvironmentSelectorFeature(continueHandler: continueHandler)
        }))
    }
}

private struct EnvironmentSelectorButtonStyle: ButtonStyle {
    static let active = Self(isActive: true)
    static let inActive = Self(isActive: false)

    var isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(Color(.text, .primary))
            .font()
            .padding(.vertical, .themeSpacing8)
            .padding(.horizontal, .themeSpacing16)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(.themeRadius8)
    }

    func backgroundColor(isPressed: Bool) -> Color {
        var style: AppTheme.Style = [.interactive]
        style.insert(isActive ? [] : .weak)
        return Color(.background, style)
    }
}

extension View {
    @ViewBuilder
    func availabilitySafeContentMargins(
        _ edges: Edge.Set = .all,
        _ insets: EdgeInsets
    ) -> some View {
        if #available(iOS 17, *) {
            self.contentMargins(edges, insets)
        } else {
            self
        }
    }
}

#Preview {
    EnvironmentSelectorMobileView(store: Store(
        initialState: EnvironmentSelectorFeature.State(
            apiEndpoint: "https://vpn-api.proton.me",
            atlasSecret: String((0..<32).map { _ in "0123456789abcdefABCDEF".randomElement()! }),
            atlasSecretFetchURLString: "",
            overrides: [.empty()]
        ),
        reducer: { EnvironmentSelectorFeature() }
    ))
    .preferredColorScheme(.dark)
}
