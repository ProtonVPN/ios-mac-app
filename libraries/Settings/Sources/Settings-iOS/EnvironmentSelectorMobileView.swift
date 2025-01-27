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
        Section {
            Text(store.apiEndpoint)
                .themeFont(.body1(.regular))
                .padding(.top, .themeSpacing2)
        } header: {
            Text("Selected Environment").font(.headline)
        } footer: {
            sendActionButton(title: "Use and continue",
                             action: .useAndContinueButtonTapped)
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

        Section {
            HStack {
                TextField("Environment URL", text: $store.newApiEndpointURLString)
                    .accessibilityIdentifier("customEnvironmentTextField") // Needed for automation
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            HStack {
                TextField("Atlas Secret", text: $store.atlasSecret)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

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
        } header: {
            Text("Change Environment").font(.headline)
        } footer: {
            changeEnvironmentCaption
        }
    }

    @ViewBuilder
    var featureOverridesSection: some View {
        Section(header: Text("Feature Overrides").font(.headline)) {
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

    func sendActionButton(title: String,
                          action: EnvironmentSelectorFeature.Action) -> some View {
        HStack {
            Spacer()
            Button(title) {
                store.send(action)
            }
            .buttonStyle(EnvironmentSelectorButtonStyle.active)
            .padding(.bottom, .themeSpacing6)
            Spacer()
        }
    }

    @ViewBuilder
    var bottomButtonsSection: some View {
        Section {

        } header: {
            Text("Apply changes").font(.headline)
        } footer: {
            VStack {
                sendActionButton(title: "Change and kill the app",
                                 action: .changeAndKillAppButtonTapped)
                sendActionButton(title: "Reset to production and kill the app",
                                 action: .resetAndKillAppButtonTapped)
            }
        }
    }

    public var body: some View {
        WithPerceptionTracking {
            Form {
                selectedEnvironmentSection
                changeEnvironmentSection
                featureOverridesSection
                bottomButtonsSection
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
