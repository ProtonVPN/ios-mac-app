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
import Ergonomics
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
    var submitRequest: @Sendable (OSSystemExtensionRequest) -> Void
}

extension SystemExtensionsRequestSubmissionClient: DependencyKey {
    static let liveValue: SystemExtensionsRequestSubmissionClient = .init(submitRequest: { request in
        OSSystemExtensionManager.shared.submitRequest(request)
    })
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

    @Dependency(\.profileManager) private var profileManager
    @Dependency(\.systemExtensionsRequestSubmissionClient) private var requestSubmissionClient
    @Dependency(\.vpnKeychain) private var vpnKeychain

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
                @Shared(.forceExtensionUpgrade) var forceExtensionUpgrade
                let forceUpgrade = forceExtensionUpgrade

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
                let activeTypes = includedTypes.filter(\.featureEnabled)
                guard !activeTypes.isEmpty else {
                    return .none
                }
                return makeSystemExtensionStreamEffect(
                    activeTypes: activeTypes,
                    forceUpgrade: forceUpgrade,
                    requestFactory: { type, stateChange, replacementPolicy in
                        SystemExtensionRequest.install(
                            type: type,
                            userInitiated: userInitiated,
                            stateChange: stateChange,
                            replacementPolicy: replacementPolicy
                        )
                    }
                )

            case let .service(.startUninstall(userInitiated, forceUpgrade, includedTypes)):
                let activeTypes = includedTypes.filter(\.featureEnabled)
                guard !activeTypes.isEmpty else {
                    return .none
                }
                return makeSystemExtensionStreamEffect(
                    activeTypes: activeTypes,
                    forceUpgrade: forceUpgrade,
                    requestFactory: { type, stateChange, replacementPolicy in
                        SystemExtensionRequest.uninstall(
                            type: type,
                            userInitiated: userInitiated,
                            stateChange: stateChange,
                            replacementPolicy: replacementPolicy
                        )
                    }
                )

            case let .service(.delegate(.approvalRequired(requiringApprovalTypes))):
                guard var context = state.installRequestContext else {
                    return .none
                }
                guard context.shouldStartTour else {
                    context.shouldReportTourSkipped = true
                    state.installRequestContext = context
                    return .none
                }

                @Shared(.isSubsequentLaunch) var isSubsequentLaunch
                let origin: SystemExtensionTourAlert.Origin = if isSubsequentLaunch {
                    .inAppPrompt(requiringApprovalTypes.map(\.tourFeature))
                } else {
                    .firstAppLaunch
                }

                let requestID = context.requestID
                return .run { send in
                    await MainActor.run {
                        @Dependency(\.windowService) var windowService
                        windowService.openSystemExtensionGuideWindow(
                            origin: origin,
                            cancelledHandler: {
                                Task { await send(.installTourCancelled(requestID)) }
                            }
                        )
                    }
                }

            case let .installTourCancelled(requestID):
                guard var context = state.installRequestContext,
                      context.requestID == requestID else {
                    return .none
                }
                context.didCancelTour = true
                state.installRequestContext = context
                return .run { _ in
                    await MainActor.run {
                        AppEvent.systemExtensionTourCancelled.post()
                    }
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
                    return .run { send in
                        await MainActor.run {
                            AppEvent.systemExtensionsAllInstalled.post(rawResult.didRequireUserApproval)
                            // Show the welcome screen on first successful sysex enable (logged-in users only).
                            @Dependency(\.windowService) var windowService
                            @Dependency(\.vpnKeychain) var vpnKeychain
                            @Shared(.welcomed) var welcomed
                            if !welcomed,
                               (try? vpnKeychain.fetchCached()) != nil {
                                windowService.presentKeyModal(
                                    viewController: WelcomeViewController(windowService: windowService),
                                    activatingApp: false
                                )
                                $welcomed.withLock { $0 = true }
                            }
                        }
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
        @Shared(.connectionProtocol) var connectionProtocol
        return vpnKeychain.userIsLoggedIn &&
            (
                connectionProtocol.requiresSystemExtension ||
                    profileManager.customProfiles().contains(where: \.connectionProtocol.requiresSystemExtension) == true
            )
    }

    private func makeSystemExtensionStreamEffect(
        activeTypes: [SystemExtensionType],
        forceUpgrade: Bool,
        requestFactory: @escaping (
            SystemExtensionType,
            @escaping (SystemExtensionRequest.State) -> Void,
            @escaping (ExtensionInfo, ExtensionInfo) -> Bool
        ) -> SystemExtensionRequest
    ) -> Effect<Action> {
        .run { send in
            var pendingTerminalTypes = Set(activeTypes)

            let stream = AsyncStream<(SystemExtensionType, SystemExtensionRequest.State)> { continuation in
                for type in activeTypes {
                    let request = requestFactory(
                        type,
                        { requestState in
                            continuation.yield((type, requestState))

                            let isTerminal = switch requestState {
                            case .succeeded, .failed, .cancelled, .superseded:
                                true
                            case .replacing, .userActionRequired:
                                false
                            }

                            guard isTerminal else { return }
                            pendingTerminalTypes.remove(type)
                            if pendingTerminalTypes.isEmpty {
                                continuation.finish()
                            }
                        },
                        { existing, newExtension in
                            existing < newExtension || forceUpgrade
                        }
                    )

                    requestSubmissionClient.submitRequest(request.osRequest)
                }
            }

            for await (type, requestState) in stream {
                await send(.service(.requestTransitioned(type: type, state: requestState)))
            }
        }
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
