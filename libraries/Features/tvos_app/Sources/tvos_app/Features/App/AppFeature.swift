//
//  Created on 25/04/2024.
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

import CommonNetworking
import ComposableArchitecture
import Connection
import ModalsServices
import ProtonCoreFeatureFlags

import struct Domain.Alert
import enum VPNShared.StorageKeys

/// Some business logic requires communication between reducers. This is facilitated by the parent feature, which
/// listens to actions coming from one child, and sends the relevant action to the other child. This allows features to
/// function independently in completely separate modules.
///
/// For example, for the sign-in flow:
///
/// ```
/// AppFeature {
///     SessionNetworkingFeature,
///     SignInFeature,
///     MainFeature { ... }
/// }
/// ```
///
/// If `SignInFeature` is responsible for logging in the user. Once the user has been signed in, it can send an action
/// such as `signInFinished(credentials: AuthCredentials)`. This is a delegate action that isn't handled by the
/// `SignInFeature`, but is instead handled by the `AppFeature`, which passes  a `SessionNetworkingFeature` action.
///
/// The reverse of this flow is used for logging out, where a user action from the `MainFeature` is observed by the
/// `AppFeature`, at which it sends a `SessionNetworkingFeature.Action` which is handled by the `SessionNetworkingFeature`
@Reducer
struct AppFeature {
    @CasePathable
    @Reducer
    enum Screen {
        case loading(LoadingFeature)
        case main(MainFeature)
        case welcome(WelcomeFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Shared(.userDisplayName) var userDisplayName: String?
        @Shared(.userEmail) var userEmail: String?
        @Shared(.userTier) var userTier: Int?
        @Shared(.connectionState) var connectionState: ConnectionState = .resolving

        var screen: Screen.State = .loading(.init())
        var connection = ConnectionFeature.State.initialState
        @Presents var alert: AlertState<Action.Alert>?

        /// Determines which root screen should be active.
        var networking: SessionNetworkingFeature.State = .unauthenticated(nil)
        var shouldSignOutAfterDisconnecting: Bool = false
        var shouldPresentNetworkFailureAlert = false
    }

    enum Action {
        case screen(Screen.Action)

        case onAppearTask
        case requestSignOut

        case incomingAlert(Domain.Alert)
        case alert(PresentationAction<Alert>)

        case networking(SessionNetworkingFeature.Action)
        case connection(ConnectionFeature.Action)

        case errorOccurred(Error)
        case signOut

        @CasePathable
        enum Alert {
            case signOut
            case retryConnection
            case getApplicationLogs
        }
    }

    @Dependency(\.alertService) private var alertService

    var body: some Reducer<State, Action> {
        Scope(state: \.networking, action: \.networking) {
            SessionNetworkingFeature()
        }
        Scope(state: \.connection, action: \.connection) {
            ConnectionFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppearTask:
                prepareEnvironment()
                setFeatureFlagOverrides()

                var effects: [Effect<AppFeature.Action>] = [
                    .send(.networking(.startObserving)),
                    .run { send in
                        for await alert in await alertService.alerts() {
                            await send(.incomingAlert(alert))
                        }
                    },
                ]
                if case .unauthenticated = state.networking {
                    effects.insert(.send(.networking(.startAcquiringSession(.signingIn))), at: 0)
                }

                return .merge(effects)

            // Screens action

            case let .screen(.welcome(.signInFinished(with: credentials))):
                return .send(.networking(.forkedSessionAuthenticated(.success(credentials))))

            case .screen(.welcome(.destination(.dismiss))):
                guard state.shouldPresentNetworkFailureAlert else { return .none }
                guard case .unauthenticated(.network) = state.networking else { return .none }
                state.alert = Self.networkRequestFailedAlert
                return .none

            case .screen(.welcome(.upsellExited)):
                state.alert = Self.signOutAlert
                return .none

            case .screen(.welcome(.upsellProductsLoadingFailed)):
                return .send(.requestSignOut)

            case let .screen(.welcome(.upsold(tier: tier))):
                // We already have a session at this point. Updating tier will dismiss the upsell flow.
                state.$userTier.withLock { $0 = tier }
                state.screen = .main(.init())
                return .none

            case .screen(.main(.launchConnection)):
                return .send(.connection(.input(.onLaunch)))

            case let .screen(.main(.connect(intent))):
                return .send(.connection(.input(.connect(intent))))

            case .screen(.main(.disconnect)):
                return .send(.connection(.input(.disconnect)))

            case .screen(.main(.signOut)),
                 .requestSignOut:
                return requestSignOut(&state)

            case .screen:
                return .none

            // Sign out

            case .signOut:
                state.shouldSignOutAfterDisconnecting = false
                return .merge(
                    .send(.connection(.input(.onLogout))),
                    .send(.networking(.startLogout))
                )

            // Networking actions

            case .networking(.startAcquiringSession):
                state.shouldPresentNetworkFailureAlert = false
                state.alert = nil
                clearUserSessionState(&state)
                synchronizeScreenWithNetworkingState(&state)
                return .none

            case .networking(.sessionFetched(.failure)):
                state.shouldPresentNetworkFailureAlert = true
                state.alert = Self.networkRequestFailedAlert
                synchronizeScreenWithNetworkingState(&state)
                return .none

            case .networking(.sessionFetched(.success(.sessionAlreadyPresent))),
                 .networking(.sessionFetched(.success(.sessionFetchedAndAvailable))),
                 .networking(.sessionFetched(.success(.sessionUnavailableAndNotFetched))):
                synchronizeScreenWithNetworkingState(&state)
                return .none

            case .networking(.startLogout):
                clearUserSessionState(&state, includeEmail: true)
                state.screen = .welcome(.init()) // Reset welcome state before unauth flow starts.
                return .none

            case let .networking(.delegate(.tier(tier))):
                state.$userTier.withLock { $0 = tier }
                if tier > 0 {
                    if !state.screen.is(\.main) {
                        state.screen = .main(.init())
                    }
                } else {
                    if case let .welcome(welcomeState) = state.screen {
                        var updatedWelcome = welcomeState
                        updatedWelcome.destination = .upsell(.loading)
                        state.screen = .welcome(updatedWelcome)
                    } else {
                        state.screen = .welcome(.init(destination: .upsell(.loading)))
                    }
                }
                return .none

            case let .networking(.delegate(.displayName(name))):
                state.$userDisplayName.withLock { $0 = name }
                return .none

            case let .networking(.delegate(.email(email))):
                state.$userEmail.withLock { $0 = email }
                return .none

            case .networking(.delegate(.sessionExpired)):
                state.alert = Self.sessionExpiredAlert
                return .send(.requestSignOut)

            case .networking(.sessionExpired):
                // Keep current screen until requestSignOut is routed.
                // This allows main sign-out flow to run when main is present.
                return .none

            case let .connection(.delegate(.stateChanged(connectionState))):
                state.$connectionState.withLock { $0 = connectionState }
                if case .disconnected = connectionState {
                    if state.shouldSignOutAfterDisconnecting {
                        state.shouldSignOutAfterDisconnecting = false
                        return .send(.signOut)
                    }
                }
                return .none

            case let .connection(.delegate(.connectionFailed(error))):
                return .send(.errorOccurred(error))

            case .connection:
                return .none

            case .networking:
                return .none

            // Alerts

            case let .errorOccurred(error):
                return .run { _ in await alertService.feed(error) }

            case let .incomingAlert(alert):
                state.alert = alert.alertState(from: Action.Alert.self)
                return .none

            case let .alert(action):
                switch action {
                case let .presented(action):
                    switch action {
                    case .signOut:
                        return .send(.requestSignOut)
                    case .retryConnection:
                        state.shouldPresentNetworkFailureAlert = false
                        state.alert = nil
                        return .send(.networking(.startAcquiringSession(.signingIn)))
                    case .getApplicationLogs:
                        state.shouldPresentNetworkFailureAlert = true
                        state.alert = nil
                        guard case .welcome = state.screen else { return .none }
                        return .send(.screen(.welcome(.showApplicationLogs)))
                    }
                case .dismiss:
                    return .none
                }
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.screen.loading, action: \.screen.loading) {
            LoadingFeature()
        }
        .ifLet(\.screen.welcome, action: \.screen.welcome) {
            WelcomeFeature()
        }
        .ifLet(\.screen.main, action: \.screen.main) {
            MainFeature()
        }
    }

    static let sessionExpiredAlert = AlertState<Action.Alert> {
        TextState("You’ve been signed out")
    } actions: {
        ButtonState(role: .cancel) {
            TextState("Got it")
        }
    } message: {
        TextState("Sign in to continue.")
    }

    static let signOutAlert = AlertState<Action.Alert> {
        TextState("Sign out?")
    } actions: {
        ButtonState(role: .destructive, action: .send(.signOut)) {
            TextState("Sign out")
        }
        ButtonState(role: .cancel) {
            TextState("Cancel")
        }
    } message: {
        TextState("Upgrade now to use the app, or sign in with a different account if you already have Proton VPN Plus")
    }

    static let networkRequestFailedAlert = AlertState<Action.Alert> {
        TextState("Your connection failed")
    } actions: {
        ButtonState(action: .retryConnection) {
            TextState("Try again")
        }
        ButtonState(action: .getApplicationLogs) {
            TextState("Get application logs")
        }
    }

    private func setFeatureFlagOverrides() {
        FeatureFlagsRepository.shared.setFlagOverride(CoreFeatureFlagType.dynamicPlan, true)
    }

    /// In DEBUG builds, persists the atlas secret and custom environment to shared defaults.
    /// In RELEASE builds, these are always nil.
    private func prepareEnvironment() {
        @Dependency(\.storage) var storage

        storage.setValue(Bundle.atlasSecret, forKey: StorageKeys.atlasSecret)
        storage.setValue(Bundle.dynamicDomain, forKey: StorageKeys.apiEndpoint)
    }

    private func clearUserSessionState(_ state: inout State, includeEmail: Bool = false) {
        state.$userDisplayName.withLock { $0 = nil }
        state.$userTier.withLock { $0 = nil }
        if includeEmail {
            state.$userEmail.withLock { $0 = nil }
        }
    }

    private func requestSignOut(_ state: inout State) -> Effect<Action> {
        guard state.screen.is(\.main) else {
            return .send(.signOut)
        }
        guard case .disconnected = state.connectionState else {
            state.shouldSignOutAfterDisconnecting = true
            return .send(.connection(.input(.disconnect)))
        }
        return .send(.signOut)
    }

    private func synchronizeScreenWithNetworkingState(_ state: inout State) {
        switch state.networking {
        case let .unauthenticated(error):
            clearUserSessionState(&state)
            if let error, error.is(\.network) {
                if !state.screen.is(\.welcome) {
                    state.screen = .welcome(.init())
                }
            } else {
                state.screen = .loading(.init())
            }
        case let .acquiringSession(useCase):
            state.screen = switch useCase {
            case .signingOut:
                .welcome(.init())
            case .signingIn:
                .loading(.init())
            }
        case .authenticated(.unauth):
            clearUserSessionState(&state)
            if !state.screen.is(\.welcome) {
                state.screen = .welcome(.init())
            }
        case .authenticated(.auth):
            guard let tier = state.userTier else {
                state.screen = .loading(.init())
                return
            }
            if tier > 0 {
                if !state.screen.is(\.main) {
                    state.screen = .main(.init())
                }
            } else {
                if case let .welcome(welcomeState) = state.screen {
                    var updatedWelcome = welcomeState
                    updatedWelcome.destination = .upsell(.loading)
                    state.screen = .welcome(updatedWelcome)
                } else {
                    state.screen = .welcome(.init(destination: .upsell(.loading)))
                }
            }
        }
    }
}

extension Alert {
    func alertState<Action>(from _: Action.Type) -> AlertState<Action> {
        let title = TextState(String(localized: title))
        let message = TextState(String(localized: message))
        return AlertState<Action>(title: { title }, message: { message })
    }
}

extension AppFeature.Screen.State: Equatable {}
