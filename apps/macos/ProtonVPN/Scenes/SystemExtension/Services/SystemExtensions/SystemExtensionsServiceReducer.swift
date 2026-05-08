//
//  Created on 04/05/2026 by Max Kupetskyi.
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
import LegacyCommon

enum SystemExtensionsOperationKind: Equatable, Hashable {
    case install
    case uninstall
}

/// Represents the result of checking/installing system extensions.
public typealias SystemExtensionResult = Result<SystemExtensionInstallationSuccess, SystemExtensionInstallationFailure>

public enum SystemExtensionInstallationSuccess: Sendable {
    /// The extension was not previously on the system, and has been installed.
    case installed
    /// An earlier version of the extension was installed, and has now been upgraded.
    case upgraded
    /// The same version of the extension was installed, and no action was taken.
    case alreadyThere
}

public enum SystemExtensionInstallationFailure: Error, Sendable {
    /// Installation of extensions requires user approval, but the system extension tour was not shown.
    case tourSkipped
    /// Installation of extensions requires user approval, but the system extension was cancelled by the user.
    case tourCancelled
    /// An error occurred while performing the installation.
    case installationError(internalError: Error)
}

/// Side-effect-free install result used by TCA orchestration layers.
public struct SystemExtensionRawInstallationResult: Sendable {
    public let accumulated: SystemExtensionResult
    public let individualResults: [SystemExtensionType: SystemExtensionResult]
    public let didRequireUserApproval: Bool

    public init(
        accumulated: SystemExtensionResult,
        individualResults: [SystemExtensionType: SystemExtensionResult],
        didRequireUserApproval: Bool
    ) {
        self.accumulated = accumulated
        self.individualResults = individualResults
        self.didRequireUserApproval = didRequireUserApproval
    }
}

@Reducer
struct SystemExtensionsServiceReducer {
    @ObservableState
    struct State: Equatable {
        var currentOperation: SystemExtensionsOperationKind?
        var pendingTypes: Set<SystemExtensionType> = []
        var states: [SystemExtensionType: SystemExtensionRequest.State] = [:]
        var approvalRequiredTypes: Set<SystemExtensionType> = []
        var lastNotifiedApprovalTypes: Set<SystemExtensionType> = []
    }

    enum Action {
        case startInstall(userInitiated: Bool, forceUpgrade: Bool, includedTypes: [SystemExtensionType])
        case startUninstall(userInitiated: Bool, forceUpgrade: Bool, includedTypes: [SystemExtensionType])
        case requestTransitioned(type: SystemExtensionType, state: SystemExtensionRequest.State)
        case clearCurrentOperation
        case delegate(Delegate)

        @CasePathable
        enum Delegate {
            case approvalRequired(types: [SystemExtensionType])
            case installCompleted(result: SystemExtensionRawInstallationResult)
            case uninstallCompleted
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startInstall(_, _, includedTypes):
                let types = includedTypes.filter(\.featureEnabled)
                state.currentOperation = .install
                state.pendingTypes = Set(types)
                state.states = [:]
                state.approvalRequiredTypes = []
                state.lastNotifiedApprovalTypes = []
                guard !types.isEmpty else {
                    return .send(.delegate(.installCompleted(
                        result: .init(
                            accumulated: .success(.alreadyThere),
                            individualResults: [:],
                            didRequireUserApproval: false
                        )
                    )))
                }
                return .none

            case let .startUninstall(_, _, includedTypes):
                let types = includedTypes.filter(\.featureEnabled)
                state.currentOperation = .uninstall
                state.pendingTypes = Set(types)
                state.states = [:]
                state.approvalRequiredTypes = []
                state.lastNotifiedApprovalTypes = []
                guard !types.isEmpty else {
                    return .send(.delegate(.uninstallCompleted))
                }
                return .none

            case let .requestTransitioned(type, requestState):
                state.states[type] = requestState
                if case .userActionRequired = requestState {
                    state.approvalRequiredTypes.insert(type)
                }
                if requestState.isTerminal {
                    state.pendingTypes.remove(type)
                }

                if !state.approvalRequiredTypes.isEmpty,
                   state.lastNotifiedApprovalTypes != state.approvalRequiredTypes {
                    state.lastNotifiedApprovalTypes = state.approvalRequiredTypes
                    return .send(
                        .delegate(.approvalRequired(
                            types: state.approvalRequiredTypes.sorted { $0.rawValue < $1.rawValue }
                        ))
                    )
                }

                guard state.pendingTypes.isEmpty,
                      let operation = state.currentOperation else {
                    return .none
                }

                switch operation {
                case .install:
                    let installResult = Self.processExtensionResults(
                        installationResults: state.states,
                        didRequireUserApproval: !state.approvalRequiredTypes.isEmpty
                    )
                    return .concatenate(
                        .send(.delegate(.installCompleted(result: installResult))),
                        .send(.clearCurrentOperation)
                    )
                case .uninstall:
                    return .concatenate(
                        .send(.delegate(.uninstallCompleted)),
                        .send(.clearCurrentOperation)
                    )
                }

            case .clearCurrentOperation:
                state.currentOperation = nil
                state.pendingTypes = []
                state.states = [:]
                state.approvalRequiredTypes = []
                state.lastNotifiedApprovalTypes = []
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private static func processExtensionResults(
        installationResults: [SystemExtensionType: SystemExtensionRequest.State],
        didRequireUserApproval: Bool
    ) -> SystemExtensionRawInstallationResult {
        var results: [SystemExtensionType: SystemExtensionResult] = [:]
        var accumulated: SystemExtensionResult = .success(.alreadyThere)

        for (type, installationResult) in installationResults {
            let individualResult: SystemExtensionResult
            switch installationResult {
            case .cancelled, .superseded:
                individualResult = .success(.alreadyThere)
            case .succeeded:
                individualResult = .success(didRequireUserApproval ? .installed : .upgraded)
            case let .failed(error):
                individualResult = .failure(.installationError(internalError: error))
            default:
                log.assertionFailure("\(type.rawValue) had unexpected final state \(installationResult)")
                individualResult = .success(.alreadyThere)
            }

            results[type] = individualResult

            if case .failure = accumulated {
                continue
            }

            switch individualResult {
            case let .failure(error):
                accumulated = .failure(error)
            case .success(.alreadyThere):
                break
            case .success:
                accumulated = .success(didRequireUserApproval ? .installed : .upgraded)
            }
        }

        return .init(
            accumulated: accumulated,
            individualResults: results,
            didRequireUserApproval: didRequireUserApproval
        )
    }
}

private extension SystemExtensionRequest.State {
    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .cancelled, .superseded:
            true
        case .replacing, .userActionRequired:
            false
        }
    }
}
