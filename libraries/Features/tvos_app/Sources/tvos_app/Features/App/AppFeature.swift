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

        var screen: Screen.State = .loading(.init())
        @Presents var alert: AlertState<Action.Alert>?

        /// Determines which root screen should be active.
        var networking: SessionNetworkingFeature.State = .unauthenticated(nil)
        var shouldSignOutAfterDisconnecting: Bool = false
        var shouldPresentNetworkFailureAlert = false
        var isSigningOut = false
    }

    enum Action {
        case screen(Screen.Action)

        case onAppearTask
        case requestSignOut

        case incomingAlert(Domain.Alert)
        case alert(PresentationAction<Alert>)

        case networking(SessionNetworkingFeature.Action)

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
                    effects.insert(.send(.networking(.startAcquiringSession)), at: 0)
                }

                return .merge(effects)

            // Screens action

            case .screen(.main(.signOut)):
                guard case let .main(mainState) = state.screen else { return .none }
                guard case .disconnected = mainState.connectionState else {
                    state.shouldSignOutAfterDisconnecting = true
                    return .send(.screen(.main(.connection(.input(.disconnect)))))
                }
                return .send(.signOut)

            case .screen(.main(.connectionDisconnected)):
                if state.shouldSignOutAfterDisconnecting {
                    // Now that VPN is fully disconnected, we can clear keychains and acquire an unauth session
                    state.shouldSignOutAfterDisconnecting = false
                    return .send(.signOut)
                }
                return .none

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

            case .screen:
                return .none

            // Sign out

            case .requestSignOut:
                guard state.screen.is(\.main) else {
                    return .send(.signOut)
                }
                return .send(.screen(.main(.signOut)))

            case .signOut:
                state.shouldSignOutAfterDisconnecting = false
                return .send(.networking(.startLogout))

            // Networking actions

            case .networking(.startAcquiringSession):
                state.shouldPresentNetworkFailureAlert = false
                state.alert = nil
                state.$userTier.withLock { $0 = nil }
                state.$userDisplayName.withLock { $0 = nil }
                if state.isSigningOut, state.screen.is(\.main) {
                    // Keep main alive until its in-flight sign-out effects drain.
                } else {
                    state.screen = state.isSigningOut ? .welcome(.init()) : .loading(.init())
                }
                return .none

            case let .networking(.sessionFetched(.failure(error))):
                state.shouldPresentNetworkFailureAlert = true
                state.alert = Self.networkRequestFailedAlert
                state.isSigningOut = false
                state.$userTier.withLock { $0 = nil }
                state.$userDisplayName.withLock { $0 = nil }
                if SessionFetchingError.network(internalError: error).is(\.network) {
                    if !state.screen.is(\.welcome) {
                        state.screen = .welcome(.init())
                    }
                } else {
                    state.screen = .loading(.init())
                }
                return .none

            case .networking(.startLogout):
                state.isSigningOut = true
                state.$userTier.withLock { $0 = nil }
                state.$userDisplayName.withLock { $0 = nil }
                state.$userEmail.withLock { $0 = nil }
                if !state.screen.is(\.main) {
                    state.screen = .welcome(.init()) // Reset welcome state before unauth flow starts
                }
                return .none

            case let .networking(.delegate(.tier(tier))):
                state.$userTier.withLock { $0 = tier }
                guard !state.isSigningOut else { return .none }
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

            case .networking:
                if state.isSigningOut {
                    // Logout transition is complete once we are no longer on an authenticated auth session.
                    if case .authenticated(.auth) = state.networking {
                    } else {
                        state.isSigningOut = false
                    }
                }
                switch state.networking {
                case let .unauthenticated(error):
                    state.$userTier.withLock { $0 = nil }
                    state.$userDisplayName.withLock { $0 = nil }
                    if let error, error.is(\.network) {
                        if !state.screen.is(\.welcome) {
                            state.screen = .welcome(.init())
                        }
                    } else {
                        state.screen = .loading(.init())
                    }
                case .acquiringSession:
                    state.screen = .loading(.init())
                case .authenticated(.unauth):
                    state.$userTier.withLock { $0 = nil }
                    state.$userDisplayName.withLock { $0 = nil }
                    if !state.screen.is(\.welcome) {
                        state.screen = .welcome(.init())
                    }
                case .authenticated(.auth):
                    guard !state.isSigningOut else {
                        state.screen = .welcome(.init())
                        return .none
                    }
                    guard let tier = state.userTier else {
                        state.screen = .loading(.init())
                        return .none
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
                return .none

            // Alerts

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
                        return .send(.networking(.startAcquiringSession))
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
}

extension Alert {
    func alertState<Action>(from _: Action.Type) -> AlertState<Action> {
        let title = TextState(String(localized: title))
        let message = TextState(String(localized: message))
        return AlertState<Action>(title: { title }, message: { message })
    }
}

extension AppFeature.Screen.State: Equatable {}
