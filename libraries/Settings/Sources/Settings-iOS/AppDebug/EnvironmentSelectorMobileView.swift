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

import SettingsShared
import Theme

public struct EnvironmentSelectorMobileView: View {
    @Binding public var store: StoreOf<DebugConfigurationFeature>

    @ViewBuilder
    var selectedEnvironmentSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text(store.apiEndpoint)
                    .themeFont(.body1(.regular))
                    .padding(.top, .themeSpacing2)
                currentEnvironmentCaption
            }
        } header: {
            Text("Selected Environment").font(.headline)
        } footer: {
            sendActionButton(
                title: "Use and continue",
                action: .useAndContinueButtonTapped
            )
        }
    }

    var currentEnvironmentCaption: Text {
        let (style, text) = store.state.currentEnvironmentCaption
        return Text(text)
            .themeFont(.caption())
            .styled(style)
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
            HStack {
                // Prefill buttons
                ForEach(store.customEnvironments) { environment in
                    prefillButton(environment: environment)
                }
            }
        } header: {
            Text("Change Environment").font(.headline)
        } footer: {
            changeEnvironmentCaption
        }
    }

    func prefillButton(environment: DebugConfigurationFeature.State.CustomEnvironment) -> some View {
        Button(environment.label) {
            store.newApiEndpointURLString = environment.url
        }
        .buttonStyle(environment.url == store.newApiEndpointURLString ? EnvironmentSelectorButtonStyle.active : EnvironmentSelectorButtonStyle.inActive)
        .padding(.trailing, .themeSpacing12)
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

    @ViewBuilder
    var localValuesOverridesSection: some View {
        Section(header: Text("Local Values Overrides").font(.headline)) {
            ForEach($store.localValuesOverrides, id: \.id) { $valueOverride in
                HStack {
                    TextField("Name \(valueOverride.index + 1)", text: $valueOverride.name)
                        .autocorrectionDisabled()
                    Spacer()
                    TextField("Value \(valueOverride.index + 1)", text: $valueOverride.value)
                        .autocorrectionDisabled()
                }
            }
            .onDelete(perform: { indexSet in
                store.send(.localValuesOverridesRemoved(indexSet))
            })
        }
        .scrollContentBackground(.hidden)
        .availabilitySafeContentMargins(.top, .init(top: 0, leading: 0, bottom: 0, trailing: 0))
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var userDefaultsCell: some View {
        SettingsCell(
            icon: .init(systemName: "text.book.closed"),
            content: .standard(title: "User Defaults", value: nil),
            accessory: .disclosure
        ) {
            store.send(.userDefaultsTapped)
        }
    }

    private var keychainCell: some View {
        SettingsCell(
            icon: .init(systemName: "key"),
            content: .standard(title: "Keychain", value: nil),
            accessory: .disclosure
        ) {
            store.send(.keychainTapped)
        }
    }

    func sendActionButton(title: String, action: DebugConfigurationFeature.Action) -> some View {
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
        Section {} header: {
            Text("Apply changes").font(.headline)
        } footer: {
            VStack {
                sendActionButton(
                    title: "Change and kill the app",
                    action: .changeAndKillAppButtonTapped
                )
                sendActionButton(
                    title: "Reset to production and kill the app",
                    action: .resetAndKillAppButtonTapped
                )
            }
        }
    }

    public var body: some View {
        NavigationStack {
            WithPerceptionTracking {
                Form {
                    selectedEnvironmentSection
                    changeEnvironmentSection
                    featureOverridesSection
                    localValuesOverridesSection
                    userDefaultsCell
                    keychainCell
                    bottomButtonsSection
                }
                .padding(.top, .themeSpacing16)
                .frame(maxWidth: Theme.Constants.readableContentWidth)
                .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
                .navigationDestination(item: $store.scope(state: \.destination?.userDefaults, action: \.destination.userDefaults)) { UserDefaultsDebugView(store: $0) }
                .navigationDestination(item: $store.scope(state: \.destination?.keychain, action: \.destination.keychain)) { KeychainDebugView(store: $0) }
            }
        }
    }

    init(store: StoreOf<DebugConfigurationFeature>) {
        _store = .constant(store)
    }

    public init(continueHandler: @escaping () -> Void) {
        self.init(store: .init(initialState: DebugConfigurationFeature.State(), reducer: {
            DebugConfigurationFeature(continueHandler: continueHandler)
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

    func backgroundColor(isPressed _: Bool) -> Color {
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
        initialState: DebugConfigurationFeature.State(
            apiEndpoint: "https://vpn-api.proton.me",
            atlasSecret: String((0 ..< 32).map { _ in "0123456789abcdefABCDEF".randomElement()! }),
            atlasSecretFetchURLString: "",
            overrides: [.empty()],
            localValuesOverrides: [.empty()]
        ),
        reducer: { DebugConfigurationFeature() }
    ))
    .preferredColorScheme(.dark)
}
