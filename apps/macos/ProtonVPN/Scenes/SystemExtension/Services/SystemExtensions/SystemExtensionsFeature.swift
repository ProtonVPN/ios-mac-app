//
//  Created on 27/04/2026 by Max Kupetskyi.
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
import Dependencies
import DependenciesMacros
import Domain
import Foundation
import LegacyCommon
import SystemExtensions
import VPNAppCore

enum SystemExtensionsRequestResponse {
    case installation(SystemExtensionRawInstallationResult)
    case uninstall
}

@DependencyClient
private struct SystemExtensionsRequestSubmissionClient {
    var submitRequest: @Sendable (OSSystemExtensionRequest) -> Void = { request in
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}

extension SystemExtensionsRequestSubmissionClient: DependencyKey {
    static let liveValue = Self()
    #if DEBUG
        static let testValue = Self(submitRequest: { request in
            // In tests we do not talk to sysextd, so complete requests immediately.
            request.delegate?.request(request, didFinishWithResult: .completed)
        })
    #endif
}

private extension DependencyValues {
    var systemExtensionsRequestSubmissionClient: SystemExtensionsRequestSubmissionClient {
        get { self[SystemExtensionsRequestSubmissionClient.self] }
        set { self[SystemExtensionsRequestSubmissionClient.self] = newValue }
    }
}

@Reducer
struct SystemExtensionsFeature {
    struct InstallRequestContext: Equatable {
        let requestID: UUID
        let includedTypes: [SystemExtensionType]
        let shouldStartTour: Bool
        var shouldReportTourSkipped = false
        var didCancelTour = false
    }

    @ObservableState
    struct State: Equatable {
        var inFlightRequestID: UUID?
        var queuedRequests: [SystemExtensionsRequest] = []
        var completedRequestIDs: [UUID] = []
        var installRequestContext: InstallRequestContext?
        var service: SystemExtensionsServiceReducer.State = .init()
    }

    enum Action {
        case enqueue(SystemExtensionsRequest)
        case startNextRequest
        case service(SystemExtensionsServiceReducer.Action)
        case installTourCancelled(UUID)
        case completed(UUID, SystemExtensionsRequestResponse)
    }

    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.systemExtensionsProfilesClient) private var profilesClient
    @Dependency(\.systemExtensionsRequestSubmissionClient) private var requestSubmissionClient
    @Dependency(\.vpnKeychain) private var vpnKeychain
    @Dependency(\.pushAlert) private var pushAlert

    var body: some ReducerOf<Self> {
        Scope(state: \.service, action: \.service) {
            SystemExtensionsServiceReducer()
        }

        Reduce { state, action in
            switch action {
            case let .enqueue(request):
                state.queuedRequests.append(request)
                return state.inFlightRequestID == nil ? .send(.startNextRequest) : .none

            case .startNextRequest:
                guard state.inFlightRequestID == nil else {
                    return .none
                }

                guard let nextRequest = state.queuedRequests.first else {
                    return .none
                }
                state.queuedRequests.removeFirst()

                state.inFlightRequestID = nextRequest.id
                let forceUpgrade = propertiesManager.forceExtensionUpgrade

                switch nextRequest.kind {
                case let .installOrUpdate(shouldStartTour, includedTypes):
                    state.installRequestContext = .init(
                        requestID: nextRequest.id,
                        includedTypes: includedTypes,
                        shouldStartTour: shouldStartTour
                    )
                    return .send(
                        .service(
                            .startInstall(
                                userInitiated: shouldStartTour,
                                forceUpgrade: forceUpgrade,
                                includedTypes: includedTypes
                            )
                        )
                    )

                case let .checkAndInstallOrUpdate(shouldStartTour, includedTypes):
                    guard shouldPerformInstallCheck() else {
                        let noOpResult: [SystemExtensionType: SystemExtensionResult] = Dictionary(
                            uniqueKeysWithValues: includedTypes.map { ($0, .success(.alreadyThere)) }
                        )
                        return .send(
                            .completed(
                                nextRequest.id,
                                .installation(
                                    .init(
                                        accumulated: .success(.alreadyThere),
                                        individualResults: noOpResult,
                                        didRequireUserApproval: false
                                    )
                                )
                            )
                        )
                    }
                    state.installRequestContext = .init(
                        requestID: nextRequest.id,
                        includedTypes: includedTypes,
                        shouldStartTour: shouldStartTour
                    )
                    return .send(
                        .service(
                            .startInstall(
                                userInitiated: shouldStartTour,
                                forceUpgrade: forceUpgrade,
                                includedTypes: includedTypes
                            )
                        )
                    )

                case let .uninstallAll(userInitiated):
                    return .send(
                        .service(
                            .startUninstall(
                                userInitiated: userInitiated,
                                forceUpgrade: forceUpgrade,
                                includedTypes: SystemExtensionType.allCases
                            )
                        )
                    )
                }

            case let .service(.startInstall(userInitiated, forceUpgrade, includedTypes)):
                return .run { send in
                    for type in includedTypes where type.featureEnabled {
                        let request = SystemExtensionRequest.install(
                            type: type,
                            userInitiated: userInitiated,
                            stateChange: { requestState in
                                Task { await send(.service(.requestTransitioned(type: type, state: requestState))) }
                            },
                            replacementPolicy: { existing, newExtension in
                                existing < newExtension || forceUpgrade
                            }
                        )

                        requestSubmissionClient.submitRequest(request.osRequest)
                    }
                }

            case let .service(.startUninstall(userInitiated, forceUpgrade, includedTypes)):
                return .run { send in
                    for type in includedTypes where type.featureEnabled {
                        let request = SystemExtensionRequest.uninstall(
                            type: type,
                            userInitiated: userInitiated,
                            stateChange: { requestState in
                                Task { await send(.service(.requestTransitioned(type: type, state: requestState))) }
                            },
                            replacementPolicy: { existing, newExtension in
                                existing < newExtension || forceUpgrade
                            }
                        )

                        requestSubmissionClient.submitRequest(request.osRequest)
                    }
                }

            case let .service(.delegate(.approvalRequired(requiringApprovalTypes))):
                guard var context = state.installRequestContext else {
                    return .none
                }
                guard context.shouldStartTour else {
                    context.shouldReportTourSkipped = true
                    state.installRequestContext = context
                    return .none
                }

                let origin: SystemExtensionTourAlert.Origin = if propertiesManager.isSubsequentLaunch {
                    .inAppPrompt(requiringApprovalTypes.map(\.tourFeature))
                } else {
                    .firstAppLaunch
                }

                let requestID = context.requestID
                return .run { [pushAlert] send in
                    let alert = SystemExtensionTourAlert(origin: origin, cancelHandler: {
                        Task { await send(.installTourCancelled(requestID)) }
                    })
                    pushAlert(alert)
                }

            case let .installTourCancelled(requestID):
                guard var context = state.installRequestContext,
                      context.requestID == requestID else {
                    return .none
                }
                context.didCancelTour = true
                state.installRequestContext = context
                return .run { _ in
                    AppEvent.systemExtensionTourCancelled.post()
                }

            case let .service(.delegate(.installCompleted(rawResult))):
                guard let context = state.installRequestContext else {
                    return .none
                }
                state.installRequestContext = nil

                if context.shouldReportTourSkipped {
                    let result = SystemExtensionRawInstallationResult(
                        accumulated: .failure(.tourSkipped),
                        individualResults: Dictionary(
                            uniqueKeysWithValues: context.includedTypes.map { ($0, .failure(.tourSkipped)) }
                        ),
                        didRequireUserApproval: false
                    )
                    return .send(.completed(context.requestID, .installation(result)))
                }

                if context.didCancelTour {
                    let result = SystemExtensionRawInstallationResult(
                        accumulated: .failure(.tourCancelled),
                        individualResults: Dictionary(
                            uniqueKeysWithValues: context.includedTypes.map { ($0, .failure(.tourCancelled)) }
                        ),
                        didRequireUserApproval: true
                    )
                    return .send(.completed(context.requestID, .installation(result)))
                }

                let interpretedResult = interpretRawInstallResult(rawResult, includedTypes: context.includedTypes)
                if case .success(.installed) = interpretedResult.accumulated {
                    return .run { [pushAlert] send in
                        AppEvent.systemExtensionsAllInstalled.post(rawResult.didRequireUserApproval)
                        pushAlert(SysexEnabledAlert())
                        await send(.completed(context.requestID, .installation(interpretedResult)))
                    }
                }
                return .send(.completed(context.requestID, .installation(interpretedResult)))

            case .service(.delegate(.uninstallCompleted)):
                guard let requestID = state.inFlightRequestID else {
                    return .none
                }
                return .send(.completed(requestID, .uninstall))

            case .service:
                return .none

            case let .completed(id, _):
                state.inFlightRequestID = nil
                state.installRequestContext = nil
                state.completedRequestIDs.append(id)
                return .send(.startNextRequest)
            }
        }
    }

    private func shouldPerformInstallCheck() -> Bool {
        vpnKeychain.userIsLoggedIn &&
            (
                propertiesManager.connectionProtocol.requiresSystemExtension ||
                    profilesClient.hasCustomProfilesRequiringSystemExtension()
            )
    }

    private func interpretRawInstallResult(
        _ rawResult: SystemExtensionRawInstallationResult,
        includedTypes: [SystemExtensionType]
    ) -> SystemExtensionRawInstallationResult {
        // Cancellation semantics are product-level: if approval was required but all requests resolved as
        // cancelled/superseded, treat that run as a cancelled tour.
        if rawResult.didRequireUserApproval,
           case .success(.alreadyThere) = rawResult.accumulated {
            let allAreAlreadyThere = includedTypes.allSatisfy { type in
                guard let result = rawResult.individualResults[type] else { return false }
                if case .success(.alreadyThere) = result {
                    return true
                }
                return false
            }
            if allAreAlreadyThere {
                let cancelledResults: [SystemExtensionType: SystemExtensionResult] = Dictionary(
                    uniqueKeysWithValues: includedTypes.map { ($0, .failure(.tourCancelled)) }
                )
                return .init(
                    accumulated: .failure(.tourCancelled),
                    individualResults: cancelledResults,
                    didRequireUserApproval: true
                )
            }
        }

        return rawResult
    }
}

@Reducer
struct SystemExtensionsParentFeature {
    @ObservableState
    struct State: Equatable {
        var systemExtensions = SystemExtensionsFeature.State()
    }

    enum Action {
        case systemExtensions(SystemExtensionsFeature.Action)
    }

    let onCompleted: @Sendable (UUID, SystemExtensionsRequestResponse) -> Void

    var body: some ReducerOf<Self> {
        Scope(state: \.systemExtensions, action: \.systemExtensions) {
            SystemExtensionsFeature()
        }

        Reduce { _, action in
            guard case let .systemExtensions(.completed(id, response)) = action else {
                return .none
            }
            onCompleted(id, response)
            return .none
        }
    }
}
