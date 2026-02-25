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

import ComposableArchitecture
import Dependencies
import ModalsServices
import PMLogger
import enum ProtonCorePaymentsV2.TransactionHandlerState
import class VPNShared.AuthCredentials

@Reducer
struct WelcomeFeature {
    @Reducer
    enum Destination {
        case signIn(SignInFeature)
        case welcomeInfo(WelcomeInfoFeature)
        case codeExpired(CodeExpiredFeature)
        case upsell(UpsellFeature)
        case drillDown(SettingsDrillDownFeature)
        case logs(LogsFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        @Shared(.userTier) var userTier: Int?
    }

    enum Action {
        case onAppear
        case paymentsEvent(TransactionHandlerState)
        case userTierUpdated(Int?)

        // Top level actions
        case signInFinished(with: AuthCredentials)
        case upsellExited
        case upsellProductsLoadingFailed
        case upsold(tier: Int)

        // Destination related actions
        case destination(PresentationAction<Destination.Action>)
        case showSignIn
        case showCreateAccount
        case showPrivacyPolicy
        case showTermsOfService
        case showApplicationLogs
    }

    private enum CancelId {
        case userTier
        case payments
    }

    @Dependency(\.alertService) private var alertService
    @Dependency(\.paymentsClient) private var paymentsClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .publisher {
                        state.$userTier.publisher
                            .removeDuplicates()
                            .receive(on: UIScheduler.shared)
                            .map(Action.userTierUpdated)
                    }
                    .cancellable(id: CancelId.userTier),
                    .run { send in
                        for await event in await paymentsClient.startObserving() {
                            await send(.paymentsEvent(event))
                        }
                    }
                    .cancellable(id: CancelId.payments, cancelInFlight: true)
                )
            case let .paymentsEvent(event):
                // forward payments event only if we show upsell
                guard case .upsell = state.destination else { return .none }
                return .send(.destination(.presented(.upsell(.event(event)))))
            case let .userTierUpdated(tier):
                guard let tier else { return .none }
                if tier == 0 {
                    state.destination = .upsell(.loading)
                } else if tier > 0 {
                    /// Right after logging in, we should reset the state of the welcome page, so that when the user logs out,
                    /// the welcome page will be shown, not the sign in page
                    state.destination = nil
                }
                return .cancel(id: CancelId.userTier)
            case .showSignIn:
                state.destination = .signIn(.init(authentication: .loadingSignInCode))
                return .none
            case .showCreateAccount:
                state.destination = .welcomeInfo(.createAccount)
                return .none
            case .showPrivacyPolicy:
                state.destination = .drillDown(.dynamic(.privacyPolicy))
                return .none
            case .showTermsOfService:
                state.destination = .drillDown(.eula)
                return .none
            case .showApplicationLogs:
                state.destination = .logs(.init(logSource: .app))
                return .none
            case .destination(.presented(.signIn(.signInFinished(.failure(.authenticationAttemptsExhausted))))):
                state.destination = .codeExpired(.init())
                return .none
            case let .destination(.presented(.signIn(.signInFinished(.success(credentials))))):
                return .send(.signInFinished(with: credentials))
            case .destination(.presented(.upsell(.onExit))):
                return .send(.upsellExited)
            case .destination(.presented(.upsell(.finishedLoadingProducts(.failure)))):
                return .send(.upsellProductsLoadingFailed)
            case let .destination(.presented(.upsell(.upsold(tier)))):
                return .send(.upsold(tier: tier))
            case let .destination(.presented(.signIn(.codeFetchingFinished(.failure(error))))):
                log.error("WelcomeFeature signIn code fetch failed: \(error)")
                // Since we don't retry fetching the sign-in code, let's pop back to the welcome screen
                return .concatenate(
                    .send(.destination(.dismiss)),
                    .run { _ in await alertService.feed(error) }
                )
            case .destination(.presented(.codeExpired(.generateNewCode))):
                state.destination = .signIn(.init(authentication: .loadingSignInCode))
                return .none
            case .destination:
                return .none
            case .signInFinished:
                return .none
            case .upsellExited:
                return .none
            case .upsellProductsLoadingFailed:
                return .none
            case .upsold:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

// MARK: - Destination.State Equatable Conformance

extension WelcomeFeature.Destination.State: Equatable {}
