//
//  Created on 06.12.2024.
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

import ComposableArchitecture
import Foundation
import SwiftUI
import SwiftUINavigation

import Domain
import SettingsShared
import Theme

public struct EnvironmentSelectorDesktopView: View {
    @Binding public var store: StoreOf<DebugConfigurationFeature>

    @ViewBuilder
    var selectedEnvironmentSection: some View {
        Section(header: Text("Selected Environment").font(.headline)) {
            Text(store.apiEndpoint)
                .themeFont(.body(emphasised: false))
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
            .themeFont(.footnote(emphasised: false))
            .styled(style)
    }

    @ViewBuilder
    var changeEnvironmentSection: some View {
        Section(header: Text("Change Environment").themeFont(.headline(emphasised: false))) {
            TextField("Environment URL", text: $store.newApiEndpointURLString)
                .accessibilityIdentifier("customEnvironmentTextField") // Needed for automation
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .padding(.themeSpacing4)
                .font()
                .clipShape(.rect(cornerRadius: .themeRadius4))
                .padding(.horizontal, .themeSpacing12)

            HStack {
                Text("Atlas:")
                    .styled(.weak)
                    .themeFont(.body(emphasised: false))
                    .padding(.leading, .themeSpacing12)

                TextField("Atlas Secret", text: $store.atlasSecret)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .padding(.themeSpacing4)
                    .font()
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
                Menu {
                    ForEach(VPNFeatureFlagType.allCases, id: \.rawValue) { feature in
                        Button {
                            store.send(.insert(feature: feature.rawValue))
                        } label: {
                            Text(feature.rawValue)
                        }
                    }
                } label: {
                    Text("Select from known feature flags")
                }
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
        }
    }

    private var userDefaultsCell: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Image(systemName: "text.book.closed")
            Text("User Defaults")
            Spacer()
            Image(systemName: "chevron.right")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.send(.userDefaultsTapped)
        }
    }

    @ViewBuilder
    var bottomButtonsSection: some View {
        Button("Apply and kill") {
            store.send(.changeAndKillAppButtonTapped)
        }
        .buttonStyle(EnvironmentSelectorButtonStyle.active)
        .padding(.bottom, .themeSpacing4)

        Button("Reset to prod and kill") {
            store.send(.resetAndKillAppButtonTapped)
        }
        .buttonStyle(EnvironmentSelectorButtonStyle.active)
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .center, spacing: .themeSpacing6) {
                selectedEnvironmentSection
                changeEnvironmentSection
                featureOverridesSection
                Form {
                    userDefaultsCell
                }.padding(.horizontal)
                bottomButtonsSection
            }
            .padding(.vertical, .themeSpacing16)
            .navigationTitle("Debug Configuration")
            .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
            .navigationDestination(item: $store.scope(state: \.destination?.userDefaults, action: \.destination.userDefaults)) { UserDefaultsDebugView(store: $0) }
            .frame(maxWidth: Theme.Constants.readableContentWidth)
        }
    }

    init(store: StoreOf<DebugConfigurationFeature>) {
        _store = .constant(store)
    }

    public init(continueHandler: @escaping () -> Void) {
        self.init(store: .init(
            initialState: DebugConfigurationFeature.State(),
            reducer: {
                DebugConfigurationFeature(continueHandler: continueHandler)
            }
        ))
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
        if #available(macOS 14, *) {
            self.contentMargins(edges, insets)
        } else {
            self
        }
    }
}

#Preview {
    EnvironmentSelectorDesktopView(store: Store(
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
