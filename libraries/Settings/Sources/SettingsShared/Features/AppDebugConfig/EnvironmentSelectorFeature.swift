//
//  Created on 02.12.2024.
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
import ComposableArchitecture
import Dependencies
import Theme

import CommonNetworking

import ProtonCoreFeatureFlags // Needed to create a manual override type

@Reducer
public struct DebugConfigurationFeature {
    static let reasonableAtlasSecretLength = 64

    public struct FeatureOverride: Equatable, Identifiable {
        public let id = UUID()

        /// - Note: this is sort of a hack to get accessibility identifiers working, don't rely on its value.
        package var index: Int
        public var name: String
        public var value: Bool

        public static func empty(index: Int = 0) -> Self {
            Self(index: index, name: "", value: true)
        }
    }

    @ObservableState
    public struct State: Equatable {
        public static let defaultApiUrlString = "https://vpn-api.proton.me"

        package let customEnvironments: [CustomEnvironment] = CustomEnvironment.allCases

        public let apiEndpoint: String
        public var newApiEndpointURLString: String

        public var atlasSecret: String
        public var fetchingAtlasSecret = false
        public var atlasSecretFetchURLString: String
        public var atlasSecretFetchErrorDescription: String?

        public var overrides: [FeatureOverride]

        public var currentEnvironmentCaption: (AppTheme.Style, String) {
            @Dependency(\.dohConfiguration) var doh
            let actualHost = doh.defaultHost
            if actualHost == apiEndpoint {
                return (.hint, "Environment active")
            }
            // If the custom host differs from what we've set, let's use the release host validator to find out why
            let validationResult = Result { try ReleaseHostValidator.validate(customHost: apiEndpoint) }
            return (.danger, "Environment not set {actual: \(actualHost), error: \(optional: validationResult.error)}")
        }

        public var environmentsCaption: (AppTheme.Style, String) {
            if atlasSecretFetchURLString.isEmpty, atlasSecret.isEmpty {
                return (.warning, "Atlas secret not set and neither is fetch URL. Enter a URL and tap 'Fetch' to set.")
            }

            if newApiEndpointURLString != Self.defaultApiUrlString {
                if let url = URL(string: newApiEndpointURLString), url.host() != nil {
                    if !url.path().hasSuffix("api") {
                        return (.warning, "You probably want your environment URL to end with '/api'.")
                    }
                } else {
                    return (.danger, "Make sure to enter a valid environment URL.")
                }
            }

            if !atlasSecretFetchURLString.isEmpty {
                return (.normal, """
                    Tap 'Fetch' to refresh atlas secret from
                    \(atlasSecretFetchURLString).
                    """
                )
            }

            if atlasSecret.hasPrefix("https://") {
                if let url = URL(string: atlasSecret),
                   url.host() != nil {
                    return (.success, "Hit 'Fetch' to continue...")
                } else {
                    return (.warning, "Make sure to enter a valid URL before tapping 'Fetch'.")
                }
            }

            return (
                .normal, """
                Atlas secret has been set manually. You can manually enter an atlas secret above, or enter a URL \
                and tap 'Fetch' to set it automatically.
                """
            )
        }

        @Presents public var destination: Destination.State?

        public init(
            apiEndpoint: String,
            atlasSecret: String,
            atlasSecretFetchURLString: String,
            overrides: [FeatureOverride]
        ) {
            self.apiEndpoint = apiEndpoint
            newApiEndpointURLString = apiEndpoint
            self.atlasSecret = atlasSecret
            self.atlasSecretFetchURLString = atlasSecretFetchURLString
            self.overrides = overrides
        }

        public init() {
            @Dependency(\.settingsStorage) var settingsStorage
            let settings = settingsStorage.getEnvironment()
            apiEndpoint = settings.apiEndpoint.isEmpty ? State.defaultApiUrlString : settings.apiEndpoint
            newApiEndpointURLString = apiEndpoint
            atlasSecret = settings.atlasSecret
            atlasSecretFetchURLString = settings.atlasSecretFetchURLString
            overrides = settings.featureFlagOverrides
                .sorted(by: { $0.key < $1.key })
                .enumerated()
                .reduce(into: Array(), { partialResult, element in
                    let (index, item) = element
                    partialResult.append(.init(index: index, name: item.key, value: item.value))
                }) + [.empty(index: settings.featureFlagOverrides.count)]
        }
    }

    public enum Action: BindableAction {
        case userDefaultsTapped
        case keychainTapped
        case useAndContinueButtonTapped
        case displayKillAppConfirmationAlert
        case fetchAtlasSecretButtonTapped
        case atlasSecretResponseReceived(Result<Data, Error>)
        case resetAndKillAppButtonTapped
        case changeAndKillAppButtonTapped
        case toggle(id: UUID)
        case overridesRemoved(IndexSet)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)

        public enum Alert: String {
            case killApp
            case proceed
        }
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { [continueHandler] state, action in
            switch action {
            case .userDefaultsTapped:
                state.destination = .userDefaults(.init(alert: nil, content: .none))
            case .keychainTapped:
                state.destination = .keychain(.init(alert: nil, content: .none))
            case let .atlasSecretResponseReceived(result):
                switch result {
                case let .success(data):
                    state.fetchingAtlasSecret = false

                    guard let string = String(data: data, encoding: .utf8),
                          string.count < Self.reasonableAtlasSecretLength else {
                        return .send(
                            .atlasSecretResponseReceived(.failure(URLError(.badServerResponse)))
                        )
                    }

                    if state.atlasSecret.hasPrefix("https://") {
                        state.atlasSecretFetchURLString = state.atlasSecret
                    }
                    state.atlasSecret = string
                case let .failure(error):
                    state.atlasSecretFetchErrorDescription = String(describing: error)
                }
            case .fetchAtlasSecretButtonTapped:
                let urlString = state.atlasSecret.hasPrefix("https://") ? state.atlasSecret : state.atlasSecretFetchURLString

                guard let url = URL(string: urlString) else {
                    return .send(
                        .atlasSecretResponseReceived(.failure(URLError(.badURL)))
                    )
                }

                state.fetchingAtlasSecret = true
                return .run { send in
                    let result = await Result {
                        @Dependency(\.urlSession) var urlSession
                        let (data, _) = try await urlSession.data(from: url)
                        return data
                    }

                    await send(.atlasSecretResponseReceived(result))
                }
            case .resetAndKillAppButtonTapped:
                state.newApiEndpointURLString = State.defaultApiUrlString
                return .concatenate(
                    .run { [state] send in
                        @Dependency(\.settingsStorage) var storage
                        do {
                            try storage.setEnvironment(.init(
                                apiEndpoint: "",
                                atlasSecret: "",
                                atlasSecretFetchURLString: state.atlasSecretFetchURLString,
                                featureFlagOverrides: [:]
                            ))
                        }
                    },
                    .send(.displayKillAppConfirmationAlert)
                )
            case .changeAndKillAppButtonTapped:
                if state.newApiEndpointURLString == State.defaultApiUrlString {
                    state.newApiEndpointURLString = "" // Empty value means 'production'
                }
                // Need to send alert telling user to kill the app
                return .concatenate(
                    .run { [state] send in
                        @Dependency(\.settingsStorage) var storage
                        do {
                            try storage.setEnvironment(.init(
                                apiEndpoint: state.newApiEndpointURLString,
                                atlasSecret: state.atlasSecret,
                                atlasSecretFetchURLString: state.atlasSecretFetchURLString,
                                featureFlagOverrides: state.overrides.reduce(into: [:], { partialResult, item in
                                    guard !item.name.isEmpty else { return }
                                    partialResult[item.name] = item.value
                                })
                            ))
                        }
                    },
                    .send(.displayKillAppConfirmationAlert)
                )
            case .displayKillAppConfirmationAlert:
                state.destination = .alert(AlertState {
                    TextState("Environment changed")
                } actions: {
                    ButtonState(role: .cancel, action: .proceed) {
                        TextState("OK")
                    }
                    ButtonState(role: .destructive, action: .killApp) {
                        TextState("Kill")
                    }
                } message: { [apiEndpoint = state.newApiEndpointURLString] in
                    TextState("""
                        Environment has been changed to \(apiEndpoint)

                        You need to KILL THE APP and start it again for the change to take effect.
                        """
                    )
                })
            case let .overridesRemoved(indexSet):
                state.overrides.remove(atOffsets: indexSet)

                // recompute the indices so that the text fields have the correct labels
                for index in 0 ..< state.overrides.count {
                    state.overrides[index].index = index
                }
            case let .toggle(id):
                guard let index = state.overrides.firstIndex(where: { $0.id == id }) else { break }
                state.overrides[index].value = !state.overrides[index].value
            case .binding(\.overrides):
                if state.overrides.isEmpty || state.overrides.allSatisfy({ !$0.name.isEmpty }) {
                    state.overrides.append(.empty(index: state.overrides.count))
                }
            case .binding:
                break
            case .useAndContinueButtonTapped, .destination(.presented(.alert(.proceed))):
                continueHandler?()
            case .destination(.presented(.alert)):
                exit(EXIT_SUCCESS)
            case .destination(.presented(.userDefaults(.delegate(.dismiss)))):
                state.destination = nil
            case .destination(.presented(.userDefaults)):
                break
            case .destination(.presented(.keychain)):
                break
            case .destination(.dismiss):
                state.destination = nil
            }
            return .none
        }
        .ifLet(\.$destination, action: \.destination)
        ._printChanges()
    }

    var continueHandler: (() -> Void)?

    public init(continueHandler: (() -> Void)? = nil) {
        self.continueHandler = continueHandler
    }
}

/// This struct is so that we can use `FeatureFlagsRepository` with
/// dynamically-specified feature flag names. (Most feature flags are usually
/// cases on an enum, but users want to specify the strings manually.)
public struct ManuallySpecifiedFeatureFlag: FeatureFlagTypeProtocol {
    public init?(rawValue: String) {
        self.rawValue = rawValue
    }

    public var rawValue: String
}

extension DebugConfigurationFeature {
    @Reducer
    public enum Destination {
        case userDefaults(UserDefaultsDebugFeature)
        case keychain(KeychainDebugFeature)
        case alert(AlertState<DebugConfigurationFeature.Action.Alert>)
    }
}

extension DebugConfigurationFeature.Destination.State: Equatable { }

extension DebugConfigurationFeature.State {
    public enum CustomEnvironment: Identifiable, Equatable, CaseIterable {
        case protonBTI
        case protonBlack

        public var id: String { url }

        package var url: String {
            switch self {
            case .protonBTI:
                return ObfuscatedConstants.btiAPIHost
            case .protonBlack:
                return ObfuscatedConstants.blackAPIHost
            }
        }

        package var label: String {
            switch self {
            case .protonBTI:
                return "BTI"
            case .protonBlack:
                return "Black"
            }
        }
    }
}
