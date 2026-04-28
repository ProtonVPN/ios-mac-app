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
import Domain
import Foundation
import LegacyCommon
import VPNAppCore

struct SystemExtensionsInstallOutcome {
    let accumulated: SystemExtensionResult
    let individualResults: [SystemExtensionType: SystemExtensionResult]
}

enum SystemExtensionsRequestResponse {
    case installation(SystemExtensionsInstallOutcome)
    case uninstall(DispatchTimeoutResult)
}

@Reducer
struct SystemExtensionsFeature {
    @ObservableState
    struct State: Equatable {
        var inFlightRequestID: UUID?
        var queuedRequests: [SystemExtensionsRequest] = []
        var completedRequestIDs: [UUID] = []
    }

    enum Action {
        case enqueue(SystemExtensionsRequest)
        case startNextRequest
        case completed(UUID, SystemExtensionsRequestResponse)
    }

    @Dependency(\.systemExtensionsClient) private var client
    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.systemExtensionsPresentationClient) private var presentationClient

    var body: some ReducerOf<Self> {
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

                return .run { send in
                    let response: SystemExtensionsRequestResponse
                    switch nextRequest.kind {
                    case let .installOrUpdate(shouldStartTour, includedTypes):
                        let result = await performInstallFlow(
                            shouldStartTour: shouldStartTour,
                            includedTypes: includedTypes,
                            client: client
                        )
                        response = .installation(result)

                    case let .checkAndInstallOrUpdate(shouldStartTour, includedTypes):
                        guard client.shouldPerformInstallCheck() else {
                            let noOpResult: [SystemExtensionType: SystemExtensionResult] = Dictionary(
                                uniqueKeysWithValues: includedTypes.map { ($0, .success(.alreadyThere)) }
                            )
                            response = .installation(.init(accumulated: .success(.alreadyThere), individualResults: noOpResult))
                            await send(.completed(nextRequest.id, response))
                            return
                        }
                        let result = await performInstallFlow(
                            shouldStartTour: shouldStartTour,
                            includedTypes: includedTypes,
                            client: client
                        )
                        response = .installation(result)

                    case let .uninstallAll(userInitiated, timeout):
                        let result = await client.uninstallAll(userInitiated, timeout)
                        response = .uninstall(result)
                    }

                    await send(.completed(nextRequest.id, response))
                }

            case let .completed(id, _):
                state.inFlightRequestID = nil
                state.completedRequestIDs.append(id)
                return .send(.startNextRequest)
            }
        }
    }

    private func performInstallFlow(
        shouldStartTour: Bool,
        includedTypes: [SystemExtensionType],
        client: SystemExtensionsClient
    ) async -> SystemExtensionsInstallOutcome {
        let shouldReportTourSkipped = LockIsolated(false)
        let didCancelTour = LockIsolated(false)

        let rawResult = await client.installOrUpdateRaw(
            userInitiated: shouldStartTour,
            includedTypes: includedTypes,
            onApprovalRequired: { requiringApprovalTypes in
                guard shouldStartTour else {
                    shouldReportTourSkipped.setValue(true)
                    return
                }

                let origin: SystemExtensionTourAlert.Origin = if propertiesManager.isSubsequentLaunch {
                    .inAppPrompt(requiringApprovalTypes.map(\.tourFeature))
                } else {
                    .firstAppLaunch
                }

                presentationClient.showTourAlert(origin) {
                    didCancelTour.setValue(true)
                    presentationClient.postTourCancelled()
                }
            }
        )

        if shouldReportTourSkipped.value {
            return .init(
                accumulated: .failure(.tourSkipped),
                individualResults: Dictionary(uniqueKeysWithValues: includedTypes.map { ($0, .failure(.tourSkipped)) })
            )
        }

        if didCancelTour.value {
            return .init(
                accumulated: .failure(.tourCancelled),
                individualResults: Dictionary(uniqueKeysWithValues: includedTypes.map { ($0, .failure(.tourCancelled)) })
            )
        }

        let interpretedResult = interpretRawInstallResult(rawResult, includedTypes: includedTypes)
        if case .success(.installed) = interpretedResult.accumulated {
            presentationClient.postAllInstalled(rawResult.didRequireUserApproval)
            presentationClient.showEnabledAlert()
        }
        return .init(
            accumulated: interpretedResult.accumulated,
            individualResults: interpretedResult.individualResults
        )
    }

    private func interpretRawInstallResult(
        _ rawResult: SystemExtensionRawInstallationResult,
        includedTypes: [SystemExtensionType]
    ) -> SystemExtensionsInstallOutcome {
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
                return .init(accumulated: .failure(.tourCancelled), individualResults: cancelledResults)
            }
        }

        return .init(
            accumulated: rawResult.accumulated,
            individualResults: rawResult.individualResults
        )
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
