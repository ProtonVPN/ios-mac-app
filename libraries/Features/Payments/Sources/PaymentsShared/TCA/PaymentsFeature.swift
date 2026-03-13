//
//  Created on 05/03/2026 by Max Kupetskyi.
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
import Foundation
import Strings
import VPNAppCore

@Reducer
public struct PaymentsFeature {
    public init() {}

    public enum PresentationKind: Equatable, Sendable {
        case upsell(UpsellModalType)
        case directSubscriptionManagement
    }

    @Reducer
    public enum Destination {
        case webCheckout(PaymentsWebCheckoutFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public let presentationKind: PresentationKind
        public let upsellModalType: UpsellModalType
        public let title: String
        public let subtitle: String?

        public var plans: [PlanOptionV2] = []
        public var discountByPlanID: [String: Int] = [:]
        public var selectedPlan: PlanOptionV2?
        public var isDirectSubscriptionReady: Bool = false

        public var isLoading: Bool = false
        public var isPurchaseInProgress: Bool = false

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        // MARK: - Init

        public init(
            presentationKind: PresentationKind? = nil,
            upsellModalType: UpsellModalType = .subscription,
            title: String? = nil,
            subtitle: String? = nil
        ) {
            let resolvedPresentationKind: PresentationKind = presentationKind ?? .upsell(upsellModalType)
            self.presentationKind = resolvedPresentationKind

            switch resolvedPresentationKind {
            case let .upsell(kindUpsellModalType):
                self.upsellModalType = kindUpsellModalType
                self.title = title ?? kindUpsellModalType.title
                self.subtitle = subtitle ?? kindUpsellModalType.subtitle
            case .directSubscriptionManagement:
                self.upsellModalType = upsellModalType
                self.title = title ?? upsellModalType.title
                self.subtitle = subtitle ?? upsellModalType.subtitle
            }
        }

        public var renewalTextForSelectedPlan: String? {
            @Dependency(\.date) var date
            @Dependency(\.calendar) var calendar
            let twoYearsFromNow = calendar.date(byAdding: .year, value: 2, to: date.now)
            guard let selectedPlan, let twoYearsFromNow else { return nil }
            let dateString = DateFormatter.renewalDateFormatter.string(from: twoYearsFromNow)
            return selectedPlan.renews(at: dateString)
        }
    }

    @CasePathable
    public enum Action {
        case onAppear
        case plansResponse(Result<[PlanOptionV2], Error>)
        case directSubscriptionPreparationCompleted
        case loadingFailed(Error)
        case directSubscriptionDismissed
        case selectedPlanChanged(PlanOptionV2)
        case validateTapped
        case validateResponse(Result<ValidationResult, Error>)
        case notNowTapped

        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case completed
            case dismissed
            case engaged(planId: String, purchaseType: PlanOptionV2.PlanType)
            case createAccountFirstRequested
        }

        @CasePathable
        public enum Alert {
            case createAccountFirst
            case retryLoading
            case dismissError
            case dismissUpgradeUnavailable
        }
    }

    public enum ValidationResult: Equatable {
        case purchased
        case presentWebCheckout(URL)
    }

    @Dependency(\.paymentsClient) private var paymentsClient
    @Dependency(\.credentiallessHelper) private var credentiallessHelper

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.isDirectSubscriptionReady = false
                let presentationKind = state.presentationKind

                return .run { [paymentsClient] send in
                    let availability = await paymentsClient.availability()
                    guard case .available = availability else {
                        if case let .unavailable(localizedReason) = availability {
                            await send(.loadingFailed(PaymentsError.upgradeUnavailable(localizedReason)))
                        }
                        return
                    }

                    switch presentationKind {
                    case .directSubscriptionManagement:
                        await send(.directSubscriptionPreparationCompleted)

                    case .upsell:
                        let plans = try await paymentsClient.retrievePlans().sorted { $0.storePricePerMonth < $1.storePricePerMonth }
                        await send(.plansResponse(.success(plans)))
                    }
                } catch: { error, send in
                    await send(.loadingFailed(error))
                }

            case let .plansResponse(.success(plans)):
                state.isLoading = false
                state.plans = plans
                state.discountByPlanID = plans.reduce(into: [:]) { partialResult, plan in
                    partialResult[plan.id] = paymentsClient.availableDiscount(plan)
                }
                state.selectedPlan = plans.first
                return .none

            case .directSubscriptionPreparationCompleted:
                state.isLoading = false
                state.isDirectSubscriptionReady = true
                return .none

            case let .loadingFailed(error):
                state.isLoading = false
                state.isPurchaseInProgress = false
                state.alert = mapErrorToAlert(error)
                return .none

            case .directSubscriptionDismissed:
                return .send(.delegate(.dismissed))

            case let .plansResponse(.failure(error)):
                state.isLoading = false
                state.isPurchaseInProgress = false
                state.alert = mapErrorToAlert(error)
                return .none

            case let .selectedPlanChanged(plan):
                state.selectedPlan = plan
                return .none

            case .validateTapped:
                guard let selectedPlan = state.selectedPlan else { return .none }
                state.isPurchaseInProgress = true
                let selectedPlanID = selectedPlan.id
                let selectedPlanPurchaseType = selectedPlan.purchaseType
                return .run { [paymentsClient, credentiallessHelper] send in
                    await send(.delegate(.engaged(planId: selectedPlanID, purchaseType: selectedPlanPurchaseType)))
                    if credentiallessHelper.isCredentialLess() {
                        await send(.validateResponse(.failure(PaymentsError.credentialless)))
                        return
                    }

                    if selectedPlan.purchaseType == .web {
                        guard let url = await paymentsClient.startWebCheckoutSession() else {
                            await send(.validateResponse(.failure(PaymentsError.missingWebCheckoutURL)))
                            return
                        }
                        await send(.validateResponse(.success(.presentWebCheckout(url))))
                        return
                    }

                    do {
                        try await paymentsClient.purchase(selectedPlan)
                        await send(.validateResponse(.success(.purchased)))
                    } catch {
                        await send(.validateResponse(.failure(error)))
                    }
                }

            case let .validateResponse(.success(result)):
                switch result {
                case .purchased:
                    state.isPurchaseInProgress = false
                    return .send(.delegate(.completed))
                case let .presentWebCheckout(url):
                    state.isPurchaseInProgress = false
                    state.destination = .webCheckout(.init(url: url))
                    return .none
                }

            case let .validateResponse(.failure(error)):
                state.isPurchaseInProgress = false
                if case PaymentsError.credentialless = error {
                    state.alert = Self.createAccountFirstAlert
                    return .none
                }
                state.alert = mapErrorToAlert(error)
                return .none

            case .notNowTapped:
                return .send(.delegate(.dismissed))

            case .destination(.presented(.webCheckout(.delegate(.completed)))):
                return .send(.delegate(.completed))

            case .destination(.presented(.webCheckout(.delegate(.cancelled)))):
                state.destination = nil
                return .none

            case .destination:
                return .none

            case .alert(.presented(.createAccountFirst)):
                return .send(.delegate(.createAccountFirstRequested))

            case .alert(.presented(.retryLoading)):
                return .send(.onAppear)

            case .alert(.presented(.dismissError)),
                 .alert(.presented(.dismissUpgradeUnavailable)):
                if case .directSubscriptionManagement = state.presentationKind {
                    return .send(.delegate(.dismissed))
                }
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension PaymentsFeature {
    static var createAccountFirstAlert: AlertState<Action.Alert> {
        AlertState {
            TextState(Localizable.createAccountFirstBeforeUpgrade)
        } actions: {
            ButtonState(action: .send(.createAccountFirst)) {
                TextState(Localizable.createAccountContinueCreating)
            }
            ButtonState(role: .cancel) {
                TextState(Localizable.createAccountCancelUpgrade)
            }
        } message: {
            TextState(Localizable.createAccountIfCloseNoUpgrade)
        }
    }

    func mapErrorToAlert(_ error: Error) -> AlertState<Action.Alert> {
        if case let PaymentsError.upgradeUnavailable(localizedReason) = error {
            return AlertState {
                TextState(Localizable.upgradeUnavailableTitle)
            } actions: {
                ButtonState(role: .cancel, action: .send(.dismissUpgradeUnavailable)) {
                    TextState(Localizable.ok)
                }
            } message: {
                TextState(localizedReason ?? Localizable.upgradeUnavailableBody)
            }
        }

        return AlertState {
            TextState(Localizable.errorUnknownTitle)
        } actions: {
            ButtonState(action: .send(.retryLoading)) {
                TextState(Localizable.retry)
            }
            ButtonState(role: .cancel, action: .send(.dismissError)) {
                TextState(Localizable.cancel)
            }
        } message: {
            TextState(errorMessage(error))
        }
    }

    func errorMessage(_ error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

public enum PaymentsError: LocalizedError, Equatable {
    case credentialless
    case missingWebCheckoutURL
    case upgradeUnavailable(String?)

    public var errorDescription: String? {
        switch self {
        case .credentialless:
            Localizable.createAccountFirstBeforeUpgrade
        case .missingWebCheckoutURL:
            "Could not start web checkout."
        case let .upgradeUnavailable(reason):
            reason ?? Localizable.upgradeUnavailableOnTestflight
        }
    }
}

private extension DateFormatter {
    static var renewalDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .long
        return formatter
    }
}

extension PaymentsFeature.Destination.State: Equatable {}
