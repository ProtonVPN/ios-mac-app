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
import PMLogger
import ProtonCoreLog
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
    @Dependency(\.alertService) var alertService
    @Dependency(\.paymentsClient) var paymentsClient

    @ObservableState
    struct State: Equatable {
        @Shared(.userDisplayName) var userDisplayName: String?
        @Shared(.userTier) var userTier: Int?
        var main = MainFeature.State()
        var welcome = WelcomeFeature.State()
        var upsell = UpsellFeature.State.loading

        @Presents var alert: AlertState<Action.Alert>?

        /// Determines whether we show the `MainFeature` or `WelcomeFeature` (sign in flow)
        var networking: SessionNetworkingFeature.State = .unauthenticated(nil)
        var shouldSignOutAfterDisconnecting: Bool = false
    }

    enum Action {
        case main(MainFeature.Action)
        case welcome(WelcomeFeature.Action)
        case upsell(UpsellFeature.Action)

        case onAppearTask

        case incomingAlert(Domain.Alert)
        case alert(PresentationAction<Alert>)

        case networking(SessionNetworkingFeature.Action)

        case signOut

        @CasePathable
        enum Alert {
            case signOut
        }
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.networking, action: \.networking) {
            SessionNetworkingFeature()
        }
        Scope(state: \.welcome, action: \.welcome) {
            WelcomeFeature()
        }
        Scope(state: \.main, action: \.main) {
            MainFeature()
        }
        Scope(state: \.upsell, action: \.upsell) {
            UpsellFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppearTask:
                prepareEnvironment()
                setFeatureFlagOverrides()
                setupCoreLogging()

                var effects: [Effect<AppFeature.Action>] = [
                    .send(.networking(.startObserving)),
                    .run { send in
                        for await event in await paymentsClient.startObserving() {
                            await send(.upsell(.event(event)))
                        }
                    },
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

            case .main(.settings(.alert(.presented(.signOut)))):
                guard case .disconnected = state.main.connectionState else {
                    state.shouldSignOutAfterDisconnecting = true
                    return .send(.main(.connection(.input(.disconnect))))
                }
                return .send(.signOut)

            case .main(.connection(.delegate(.stateChanged(.disconnected)))):
                if state.shouldSignOutAfterDisconnecting {
                    // Now that VPN is fully disconnected, we can clear keychains and acquire an unauth session
                    state.shouldSignOutAfterDisconnecting = false
                    return .send(.signOut)
                }
                return .none

            case .main:
                return .none

            case let .welcome(.destination(.presented(.signIn(.signInFinished(.success(credentials)))))):
                state.main.currentTab = .home
                return .send(.networking(.forkedSessionAuthenticated(.success(credentials))))

            case .welcome(.destination(.presented(.signIn(.signInFinished(.failure))))):
                return .none

            case .welcome:
                return .none

            case .networking(.startLogout):
                state.welcome = .init() // Reset welcome state
                return .none

            case let .networking(.delegate(.tier(tier))):
                state.$userTier.withLock { $0 = tier }
                return .none

            case let .networking(.delegate(.displayName(name))):
                state.$userDisplayName.withLock { $0 = name }
                return .none

            case .networking(.delegate(.sessionExpired)):
                state.alert = Self.sessionExpiredAlert
                return .send(.signOut)

            case .networking:
                return .none

            case let .incomingAlert(alert):
                state.alert = alert.alertState(from: Action.Alert.self)
                return .none

            case let .alert(action):
                switch action {
                case let .presented(action):
                    switch action {
                    case .signOut:
                        return .send(.signOut)
                    }
                case .dismiss:
                    return .none
                }

            case .upsell(.onExit):
                state.alert = Self.signOutAlert
                return .none

            case .upsell(.finishedLoadingProducts(.failure)):
                return .send(.signOut)

            case let .upsell(.upsold(tier)):
                // We already have a session at this point. Updating tier will dimiss the upsell flow
                state.$userTier.withLock { $0 = tier }
                return .none

            case .upsell:
                return .none

            case .signOut:
                state.shouldSignOutAfterDisconnecting = false
                return .concatenate(
                    .send(.main(.onLogout)),
                    .send(.networking(.startLogout))
                )
            }
        }
        .ifLet(\.$alert, action: \.alert)
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

    private func setFeatureFlagOverrides() {
        FeatureFlagsRepository.shared.setFlagOverride(CoreFeatureFlagType.dynamicPlan, true)
    }

    private func setupCoreLogging() {
        @Dependency(\.dohConfiguration) var doh
        PMLog.setExternalLoggerHost(doh.defaultHost)

        ProtonCoreLog.PMLog.callback = { message, level in
            switch level {
            case .debug, .trace:
                log.debug("\(message)", category: .core)

            case .info:
                log.info("\(message)", category: .core)

            case .warn:
                log.warning("\(message)", category: .core)

            case .error:
                log.error("\(message)", category: .core)

            case .fatal:
                log.assertionFailure("\(message)", category: .core)
            }
        }
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
        return AlertState<Action>(title: title, message: message)
    }
}
