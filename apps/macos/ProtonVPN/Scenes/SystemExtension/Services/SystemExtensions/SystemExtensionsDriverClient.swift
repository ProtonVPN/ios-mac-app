//
//  Created on 28/04/2026 by Max Kupetskyi.
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

import Dependencies
import DependenciesMacros
import Foundation
import LegacyCommon
import SystemExtensions

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
    /// An error occurred while performing the installation
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

@DependencyClient
struct SystemExtensionsDriverClient {
    var installOrUpdateRaw: @Sendable (
        _ userInitiated: Bool,
        _ includedTypes: [SystemExtensionType],
        _ replacementPolicy: @escaping @Sendable (ExtensionInfo, ExtensionInfo) -> Bool,
        _ userActionRequiredHandler: @escaping ([SystemExtensionType]) -> Void,
        _ completion: @escaping (SystemExtensionRawInstallationResult) -> Void
    ) -> Void
    var uninstallAll: @Sendable (
        _ userInitiated: Bool,
        _ timeout: DispatchTime?,
        _ replacementPolicy: @escaping @Sendable (ExtensionInfo, ExtensionInfo) -> Bool
    ) -> DispatchTimeoutResult = { _, _, _ in .success }
}

extension SystemExtensionsDriverClient: DependencyKey {
    static let liveValue: SystemExtensionsDriverClient = {
        let driver = LiveSystemExtensionsDriver()
        return .init(
            installOrUpdateRaw: { userInitiated, includedTypes, replacementPolicy, userActionRequiredHandler, completion in
                driver.installOrUpdateRaw(
                    userInitiated: userInitiated,
                    includedTypes: includedTypes,
                    replacementPolicy: replacementPolicy,
                    userActionRequiredHandler: userActionRequiredHandler,
                    completion: completion
                )
            },
            uninstallAll: { userInitiated, timeout, replacementPolicy in
                driver.uninstallAll(
                    userInitiated: userInitiated,
                    timeout: timeout,
                    replacementPolicy: replacementPolicy
                )
            }
        )
    }()

    #if DEBUG
        static let testValue: SystemExtensionsDriverClient = .init(
            installOrUpdateRaw: { _, includedTypes, _, _, completion in
                completion(
                    .init(
                        accumulated: .success(.alreadyThere),
                        individualResults: Dictionary(
                            uniqueKeysWithValues: includedTypes.map { ($0, .success(.alreadyThere)) }
                        ),
                        didRequireUserApproval: false
                    )
                )
            },
            uninstallAll: { _, _, _ in .success }
        )
    #endif
}

extension DependencyValues {
    var systemExtensionsDriverClient: SystemExtensionsDriverClient {
        get { self[SystemExtensionsDriverClient.self] }
        set { self[SystemExtensionsDriverClient.self] = newValue }
    }
}

private final class LiveSystemExtensionsDriver {
    private typealias InstallationState = [SystemExtensionType: SystemExtensionRequest.State]
    private let requestQueue = DispatchQueue(label: "ch.proton.sysex.requests")
    private var outstandingRequests: Set<SystemExtensionRequest> = []

    func installOrUpdateRaw(
        userInitiated: Bool,
        includedTypes: [SystemExtensionType],
        replacementPolicy: @escaping @Sendable (ExtensionInfo, ExtensionInfo) -> Bool,
        userActionRequiredHandler: @escaping ([SystemExtensionType]) -> Void,
        completion: @escaping (SystemExtensionRawInstallationResult) -> Void
    ) {
        var didRequireUserApproval = false

        submitInstallationRequests(
            includedTypes: includedTypes,
            userInitiated: userInitiated,
            replacementPolicy: replacementPolicy,
            userActionRequiredHandler: { installationState in
                didRequireUserApproval = true
                userActionRequiredHandler(installationState)
            },
            installationFinishedHandler: { installationResults in
                let (accumulated, results) = Self.processExtensionResults(
                    installationResults: installationResults,
                    didRequireUserApproval: didRequireUserApproval
                )
                completion(
                    .init(
                        accumulated: accumulated,
                        individualResults: results,
                        didRequireUserApproval: didRequireUserApproval
                    )
                )
            }
        )
    }

    func uninstallAll(
        userInitiated: Bool,
        timeout: DispatchTime?,
        replacementPolicy: @escaping @Sendable (ExtensionInfo, ExtensionInfo) -> Bool
    ) -> DispatchTimeoutResult {
        let group = DispatchGroup()

        for type in SystemExtensionType.allCases {
            group.enter()
            request(.uninstall(
                type: type,
                userInitiated: userInitiated,
                stateChange: { stateChange in
                    switch stateChange {
                    case .succeeded, .failed:
                        group.leave()
                    default:
                        log.error("Unexpected state transition for uninstall: \(stateChange)")
                        group.leave()
                    }
                },
                replacementPolicy: replacementPolicy,
                onFinish: { [weak self] request in
                    self?.outstandingRequests.remove(request)
                }
            ))
        }

        guard let timeout else {
            group.wait()
            return .success
        }

        return group.wait(timeout: timeout)
    }

    // MARK: - Private

    private func request(_ request: SystemExtensionRequest) {
        log.info("Submitting request \(request.osRequest.description) for \(request.osRequest.identifier)")
        outstandingRequests.insert(request)
        OSSystemExtensionManager.shared.submitRequest(request.osRequest)
    }

    private func submitInstallationRequests(
        includedTypes: [SystemExtensionType],
        userInitiated: Bool,
        replacementPolicy: @escaping @Sendable (ExtensionInfo, ExtensionInfo) -> Bool,
        userActionRequiredHandler: @escaping (([SystemExtensionType]) -> Void),
        installationFinishedHandler: @escaping ((InstallationState) -> Void)
    ) {
        let queue = DispatchQueue(label: "ch.protonvpn.sysext.status.\(UUID().uuidString)")
        var states: InstallationState = [:]
        var extensionsRequiringApproval = [SystemExtensionType]()

        let finishedInstalling = DispatchGroup()
        let installStatesKnown = DispatchGroup()

        for type in includedTypes where type.featureEnabled {
            finishedInstalling.enter()
            installStatesKnown.enter()

            let install = SystemExtensionRequest.install(
                type: type,
                userInitiated: userInitiated,
                stateChange: { stateChange in
                    var prevState: SystemExtensionRequest.State?
                    queue.sync {
                        prevState = states[type]
                        states[type] = stateChange
                    }
                    switch stateChange {
                    case .replacing:
                        break
                    case .userActionRequired:
                        queue.sync { extensionsRequiringApproval.append(type) }
                        installStatesKnown.leave()
                    case .failed, .succeeded, .superseded, .cancelled:
                        if case .userActionRequired = prevState {} else {
                            installStatesKnown.leave()
                        }
                        finishedInstalling.leave()
                    }
                },
                replacementPolicy: replacementPolicy,
                onFinish: { [weak self] request in
                    self?.outstandingRequests.remove(request)
                }
            )
            request(install)
        }

        installStatesKnown.notify(queue: requestQueue) {
            guard !extensionsRequiringApproval.isEmpty else { return }
            userActionRequiredHandler(extensionsRequiringApproval)
        }

        finishedInstalling.notify(queue: requestQueue) {
            installationFinishedHandler(states)
        }
    }

    private static func processExtensionResults(
        installationResults: InstallationState,
        didRequireUserApproval: Bool
    ) -> (accumulated: SystemExtensionResult, results: [SystemExtensionType: SystemExtensionResult]) {
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

        return (accumulated: accumulated, results: results)
    }
}
