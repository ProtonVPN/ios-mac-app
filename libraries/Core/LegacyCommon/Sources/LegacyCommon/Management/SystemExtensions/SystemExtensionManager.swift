//
//  SystemExtensionManager.swift
//  ProtonVPN - Created on 07/12/2020.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

#if os(macOS)

    import Foundation
    import SystemExtensions

    import Dependencies
    import ProtonCoreFeatureFlags

    import Domain
    import Telemetry
    import VPNAppCore

    public protocol SystemExtensionManagerFactory {
        func makeSystemExtensionManager() -> SystemExtensionManager
    }

    public enum SystemExtensionType: String, CaseIterable {
        case wireGuard = "ch.protonvpn.mac.WireGuard-Extension"
        case plutonium = "ch.protonvpn.mac.Transparent-Proxy"

        public var machServiceName: String {
            "\(DomainConstants.appIdentifierPrefix)group.\(rawValue)"
        }

        public var featureEnabled: Bool {
            switch self {
            case .wireGuard:
                true
            case .plutonium:
                VPNFeatureFlagType.plutoniumMacOS.enabled
            }
        }
    }

    /// Represents the result of checking/installing system extensions.
    public typealias SystemExtensionResult = Result<SystemExtensionInstallationSuccess, SystemExtensionInstallationFailure>

    public enum SystemExtensionInstallationSuccess {
        /// The extension was not previously on the system, and has been installed.
        case installed
        /// An earlier version of the extension was installed, and has now been upgraded.
        case upgraded
        /// The same version of the extension was installed, and no action was taken.
        case alreadyThere
    }

    public enum SystemExtensionInstallationFailure: Error {
        /// Installation of extensions requires user approval, but the system extension tour was not shown.
        case tourSkipped
        /// Installation of extensions requires user approval, but the system extension was cancelled by the user.
        case tourCancelled
        /// An error occurred while performing the installation
        case installationError(internalError: Error)
    }

    public class SystemExtensionManager: NSObject {
        static let requestQueue = DispatchQueue(label: "ch.proton.sysex.requests")

        public typealias Factory = CoreAlertServiceFactory &
            ProfileManagerFactory
        private let factory: Factory

        private typealias InstallationState = [SystemExtensionType: SystemExtensionRequest.State]

        private func processExtensionResults(installationResults: InstallationState, didRequireUserApproval: Bool) -> (accumulated: SystemExtensionResult, results: [SystemExtensionType: SystemExtensionResult]) {
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

                // Accumulate overall result with failure precedence and success upgrade/install mapping
                if case .failure = accumulated {
                    // Preserve the first failure
                } else {
                    switch individualResult {
                    case let .failure(error):
                        accumulated = .failure(error)
                    case .success(.alreadyThere):
                        break
                    case .success:
                        accumulated = .success(didRequireUserApproval ? .installed : .upgraded)
                    }
                }
            }

            // if approval was required in this run but we finished with only cancelled/superseded
            // (no success and no failure), report a cancelled tour instead of
            // success(.alreadyThere).
            if didRequireUserApproval {
                var sawSuccess = false
                var sawFailure = false
                var onlyCancelledOrSuperseded = true

                for state in installationResults.values {
                    switch state {
                    case .succeeded:
                        sawSuccess = true
                        onlyCancelledOrSuperseded = false
                    case .failed:
                        sawFailure = true
                        onlyCancelledOrSuperseded = false
                    case .cancelled, .superseded:
                        break
                    default:
                        onlyCancelledOrSuperseded = false
                    }
                }

                if !sawSuccess, !sawFailure, onlyCancelledOrSuperseded {
                    accumulated = .failure(.tourCancelled)
                }
            }

            return (accumulated: accumulated, results: results)
        }

        private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
        @Dependency(\.propertiesManager) private var propertiesManager
        @Dependency(\.vpnKeychain) private var vpnKeychain
        private lazy var profileManager: ProfileManager = factory.makeProfileManager()

        fileprivate var outstandingRequests: Set<SystemExtensionRequest> = []

        private var userIsLoggedIn: Bool {
            vpnKeychain.userIsLoggedIn
        }

        public init(factory: Factory) {
            self.factory = factory
        }

        func request(_ request: SystemExtensionRequest) {
            log.info("Submitting request \(request.request.description) for \(request.request.identifier)")

            outstandingRequests.insert(request)
            OSSystemExtensionManager.shared.submitRequest(request.request)
        }

        /// Synchronously (!) uninstall all extensions on the system, with an optional timeout.
        public func uninstallAll(userInitiated _: Bool, timeout: DispatchTime? = nil) -> DispatchTimeoutResult {
            let group = DispatchGroup()

            for type in SystemExtensionType.allCases {
                group.enter()
                request(.uninstall(type: type, manager: self) { stateChange in
                    switch stateChange {
                    case .succeeded, .failed:
                        group.leave()
                    default:
                        log.error("Unexpected state transition for uninstall: \(stateChange)")
                        group.leave()
                    }
                })
            }

            guard let timeout else {
                group.wait()
                return .success
            }

            return group.wait(timeout: timeout)
        }

        /// Submit installation requests for all extensions.
        ///
        /// - Parameter userActionRequiredHandler: Called with the number of extensions that require user approval.
        ///             This callback will *not* be called if no extensions require approval.
        /// - Parameter installationFinishedHandler: Called when installation is finished, regardless of success.
        /// - Returns: The submitted requests.
        private func submitInstallationRequests(
            origin: SystemExtensionEvent.Origin,
            includedTypes: [SystemExtensionType],
            userInitiated: Bool,
            userActionRequiredHandler: @escaping (([SystemExtensionType]) -> Void),
            installationFinishedHandler: @escaping ((InstallationState) -> Void)
        ) -> [SystemExtensionRequest] {
            let queue = DispatchQueue(label: "ch.protonvpn.sysext.status.\(UUID().uuidString)")
            var states: InstallationState = [:]
            var extensionsRequiringApproval = [SystemExtensionType]()
            var requests: [SystemExtensionRequest] = []

            let finishedInstalling = DispatchGroup()
            let installStatesKnown = DispatchGroup()
            let connectionProtocol = propertiesManager.connectionProtocol

            for type in includedTypes where type.featureEnabled {
                finishedInstalling.enter()
                installStatesKnown.enter()

                let activation = SystemExtensionActivationTelemetry(
                    origin: origin,
                    extensionType: SystemExtensionEvent.ExtensionType(type),
                    connectionProtocol: connectionProtocol
                )
                let install = SystemExtensionRequest.install(
                    type: type,
                    userInitiated: userInitiated,
                    activation: activation,
                    manager: self
                ) { stateChange in
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
                            // If we never transitioned through userActionRequired, that means that we didn't
                            // require user action to replace the extension, so it already exists on the system.
                            installStatesKnown.leave()
                        }
                        finishedInstalling.leave()
                    }
                }
                activation.reportAttempt()
                request(install)
                requests.append(install)
            }

            installStatesKnown.notify(queue: SystemExtensionManager.requestQueue) {
                guard !extensionsRequiringApproval.isEmpty else { return }

                userActionRequiredHandler(extensionsRequiringApproval)
            }

            finishedInstalling.notify(queue: SystemExtensionManager.requestQueue) {
                installationFinishedHandler(states)
            }

            return requests
        }

        /// Moves the approval tour of each request that waits for approval, and reports it.
        private static func reportPrompt(
            _ prompt: SystemExtensionActivationTelemetry.Prompt,
            for requests: [SystemExtensionRequest]
        ) {
            // The system delivers request callbacks on this queue, so telemetry stays on it too.
            requestQueue.async {
                requests.forEach { $0.activation?.reportPrompt(prompt) }
            }
        }

        /// Installs the specified system extensions if needed, provided the following hold true:
        /// - The user is logged in
        /// - The default connection protocol requires a system extension, OR
        /// - The user has created a custom profile containing a protocol requiring a system extension
        ///
        /// - Parameters:
        ///   - origin: Origin of the request for the telemetry.
        ///   - shouldStartTour: Whether the system extension tour should be shown if user approval is required. When false,
        ///     and approval is required, `actionHandler` will report `.failure(.tourSkipped)`.
        ///   - includedTypes: The extensions to check and install. Pass `SystemExtensionType.allCases` to include all.
        ///   - actionHandler: A completion handler invoked when installation or system extension tour complete or fail.
        public func checkAndInstallOrUpdateExtensionsIfNeeded(
            origin: SystemExtensionEvent.Origin,
            shouldStartTour: Bool,
            includedTypes: [SystemExtensionType],
            actionHandler: @escaping (SystemExtensionResult, [SystemExtensionType: SystemExtensionResult]) -> Void
        ) {
            // do not check if the user is not logged in to avoid showing the installation prompt on the
            // login screen on first start
            guard userIsLoggedIn else {
                log.debug("Aborted sysex installation because user is not logged in", category: .sysex)
                return
            }

            guard propertiesManager.connectionProtocol.requiresSystemExtension ||
                profileManager.customProfiles.contains(where: \.connectionProtocol.requiresSystemExtension) else {
                log.debug("Aborted sysex installation because it is not required by profiles and settings", category: .sysex)
                return
            }

            installOrUpdateExtensionsIfNeeded(
                origin: origin,
                shouldStartTour: shouldStartTour,
                includedTypes: includedTypes,
                actionHandler: actionHandler
            )
        }

        /// Installs or updates the specified system extensions. This will result in system extension dialogs appearing if the user has
        /// not approved any on the system yet.
        ///
        /// - Parameters:
        ///   - origin: Origin of the request for the telemetry.
        ///   - shouldStartTour: Whether the system extension tour should be shown if user approval is required. When false,
        ///     and approval is required, `actionHandler` will report `.failure(.tourSkipped)`.
        ///   - includedTypes: The extensions to install or update. Pass `SystemExtensionType.allCases` to include all.
        ///   - actionHandler: A completion handler invoked when installation or system extension tour complete or fail.
        ///                    Receives both the accumulated result and individual results for each extension type.
        public func installOrUpdateExtensionsIfNeeded(
            origin: SystemExtensionEvent.Origin,
            shouldStartTour: Bool,
            includedTypes: [SystemExtensionType],
            actionHandler: @escaping (SystemExtensionResult, [SystemExtensionType: SystemExtensionResult]) -> Void
        ) {
            var didRequireUserApproval = false
            var requests: [SystemExtensionRequest] = []

            requests = submitInstallationRequests(origin: origin, includedTypes: includedTypes, userInitiated: shouldStartTour, userActionRequiredHandler: { [unowned self] installationState in
                didRequireUserApproval = true

                guard shouldStartTour else {
                    SentryHelper.shared?.log(message: "Sysex tour ended.", extra: ["reason": "skipped"])
                    Self.reportPrompt(.answered(.skipped), for: requests)
                    let skippedResults: [SystemExtensionType: SystemExtensionResult] = Dictionary(
                        uniqueKeysWithValues: includedTypes.map { ($0, .failure(.tourSkipped)) }
                    )
                    actionHandler(.failure(.tourSkipped), skippedResults)
                    return
                }

                let tourOrigin: SystemExtensionTourAlert.Origin = if propertiesManager.isSubsequentLaunch {
                    .inAppPrompt(installationState.map(\.feature))
                } else {
                    .firstAppLaunch
                }

                let tour = SystemExtensionTourAlert(origin: tourOrigin, openedSystemSettingsHandler: {
                    Self.reportPrompt(.answered(.proceeded), for: requests)
                }, cancelHandler: {
                    SentryHelper.shared?.log(message: "Sysex tour ended.", extra: ["reason": "cancelled"])
                    Self.reportPrompt(.answered(.cancelled), for: requests)
                    DispatchQueue.main.async {
                        let cancelledResults: [SystemExtensionType: SystemExtensionResult] = Dictionary(
                            uniqueKeysWithValues: includedTypes.map { ($0, .failure(.tourCancelled)) }
                        )
                        actionHandler(.failure(.tourCancelled), cancelledResults)
                        AppEvent.systemExtensionTourCancelled.post()
                    }
                })

                Self.reportPrompt(.displayed, for: requests)
                alertService.push(alert: tour)
            }, installationFinishedHandler: { installationResults in
                var (accumulated, results) = self.processExtensionResults(installationResults: installationResults, didRequireUserApproval: didRequireUserApproval)
                log.debug("Finished installation with results: \(results)", category: .sysex)

                // Log individual results
                for (type, result) in results {
                    switch result {
                    case let .success(success):
                        SentryHelper.shared?.log(message: "Sysex installation succeeded for \(type.rawValue).", extra: ["success": success])
                    case let .failure(failure):
                        if case let .installationError(internalError) = failure {
                            SentryHelper.shared?.log(error: internalError)
                        }
                    }
                }

                // If tour was intended (shouldStartTour == true) but the run finished with only
                // cancelled/superseded (no success and no failure), report a cancelled tour instead
                // of success(.alreadyThere) to avoid silently succeeding.
                if shouldStartTour {
                    let values = installationResults.values
                    let anySuccess = values.contains { if case .succeeded = $0 { true } else { false } }
                    let anyFailure = values.contains { if case .failed = $0 { true } else { false } }
                    let allCancelledOrSuperseded = values.allSatisfy {
                        switch $0 {
                        case .cancelled, .superseded: true
                        default: false
                        }
                    }

                    if !anySuccess, !anyFailure, allCancelledOrSuperseded {
                        accumulated = .failure(.tourCancelled)
                    }
                }

                DispatchQueue.main.async {
                    actionHandler(accumulated, results)

                    if case .success(.installed) = accumulated {
                        AppEvent.systemExtensionsAllInstalled.post(didRequireUserApproval)
                        self.alertService.push(alert: SysexEnabledAlert())
                    }
                }
            })
        }
    }

    /// Wrapper class for `OSSystemExtensionRequest` that lets us keep track of individual requests more easily.
    /// Every call to a delegate function is routed through the `stateChangeCallback` property. This callback is
    /// generated uniquely for every request in the `SystemExtensionManager`, so we know the state of each
    /// installation request individually.
    public class SystemExtensionRequest: NSObject {
        typealias StateChangeCallback = (State) -> Void

        let action: Action
        let request: OSSystemExtensionRequest
        let stateChangeCallback: StateChangeCallback
        unowned let manager: SystemExtensionManager
        let userInitiated: Bool
        /// Telemetry for activation requests. Deactivation requests are not reported.
        let activation: SystemExtensionActivationTelemetry?
        @Dependency(\.propertiesManager) private var propertiesManager

        let uuid = UUID()

        enum Action {
            case install
            case uninstall
        }

        enum State {
            /// We have told sysextd we want our extension to replace an existing one in the system.
            case replacing
            /// Request has been received, but is waiting on user action to proceed.
            case userActionRequired
            /// Request has completed successfully.
            case succeeded(OSSystemExtensionRequest.Result)
            /// Request has been cancelled by the application. This can happen for a couple of reasons:
            /// - Most likely, an existing extension with the same (or greater) version is already installed.
            /// - The system asked if the application wants to replace an extension that is not recognized.
            case cancelled
            /// Request has been superseded by another one (user requested another sysext install).
            case superseded
            /// Request has failed with an error.
            case failed(Error)
        }

        /// Only opts to replace an extension if the version is higher, or if a testing flag is set in defaults.
        func shouldExtension(_ existing: ExtensionInfo, beReplacedBy newExtension: ExtensionInfo) -> Bool {
            existing < newExtension || propertiesManager.forceExtensionUpgrade
        }

        required init(
            action: Action,
            request: OSSystemExtensionRequest,
            stateChange: @escaping StateChangeCallback,
            manager: SystemExtensionManager,
            userInitiated: Bool,
            activation: SystemExtensionActivationTelemetry?
        ) {
            self.action = action
            self.request = request
            self.stateChangeCallback = stateChange
            self.manager = manager
            self.userInitiated = userInitiated
            self.activation = activation
        }

        static func install(
            type: SystemExtensionType,
            userInitiated: Bool,
            activation: SystemExtensionActivationTelemetry,
            manager: SystemExtensionManager,
            stateChange: @escaping StateChangeCallback
        ) -> Self {
            let result = Self(
                action: .install,
                request: .activationRequest(
                    forExtensionWithIdentifier: type.rawValue,
                    queue: SystemExtensionManager.requestQueue
                ),
                stateChange: stateChange,
                manager: manager,
                userInitiated: userInitiated,
                activation: activation
            )
            result.request.delegate = result
            return result
        }

        static func uninstall(
            type: SystemExtensionType,
            manager: SystemExtensionManager,
            stateChange: @escaping StateChangeCallback
        ) -> Self {
            let result = Self(
                action: .uninstall,
                request: .deactivationRequest(
                    forExtensionWithIdentifier: type.rawValue,
                    queue: SystemExtensionManager.requestQueue
                ),
                stateChange: stateChange,
                manager: manager,
                userInitiated: false,
                activation: nil
            )
            result.request.delegate = result
            return result
        }

        deinit {
            log.debug("Deinit request \(uuid.uuidString) for \(request.identifier)")
        }

        /// Records the new state for telemetry, then passes it on.
        private func changeState(_ state: State) {
            activation?.record(state)
            stateChangeCallback(state)
        }
    }

    extension SystemExtensionRequest: OSSystemExtensionRequestDelegate {
        public func request(
            _: OSSystemExtensionRequest,
            actionForReplacingExtension existing: OSSystemExtensionProperties,
            withExtension ext: OSSystemExtensionProperties
        ) -> OSSystemExtensionRequest.ReplacementAction {
            assert(
                existing.bundleIdentifier == ext.bundleIdentifier,
                "Extensions have mismatched identifiers? (\(existing.bundleIdentifier) and \(ext.bundleIdentifier))"
            )

            let shouldReplace = shouldExtension(
                .init(
                    version: existing.bundleShortVersion,
                    build: existing.bundleVersion,
                    bundleId: existing.bundleIdentifier
                ),
                beReplacedBy: .init(
                    version: ext.bundleShortVersion,
                    build: ext.bundleVersion,
                    bundleId: ext.bundleIdentifier
                )
            )

            let isExistingEnabled = existing.isEnabled && !existing.isAwaitingUserApproval

            // Allow equal-version replacement when the run is user-initiated to surface the approval flow.
            if !shouldReplace, userInitiated {
                let isEqualVersion = (existing.bundleShortVersion == ext.bundleShortVersion) && (existing.bundleVersion == ext.bundleVersion)
                if isEqualVersion {
                    activation?.installedCopy = .reinstalled(isEnabled: isExistingEnabled)
                    changeState(.replacing)
                    return .replace
                }
            }

            // Don't call changeState(.cancelled) here, we do that when sysextd calls us again
            // with `request(_:didFailWithError:)`.
            guard shouldReplace else {
                activation?.installedCopy = .kept(isEnabled: isExistingEnabled)
                return .cancel
            }

            activation?.installedCopy = .replacedOlderVersion
            changeState(.replacing)
            return .replace
        }

        public func requestNeedsUserApproval(_: OSSystemExtensionRequest) {
            changeState(.userActionRequired)
        }

        public func request(_: OSSystemExtensionRequest, didFailWithError error: Error) {
            guard let sysextError = error as? OSSystemExtensionError else {
                changeState(.failed(error))
                return
            }

            switch sysextError.code {
            case .requestCanceled:
                changeState(.cancelled)
            case .requestSuperseded:
                changeState(.superseded)
            default:
                changeState(.failed(sysextError))
            }

            manager.outstandingRequests.remove(self)
        }

        public func request(_: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
            changeState(.succeeded(result))

            manager.outstandingRequests.remove(self)
        }
    }

    private extension SystemExtensionType {
        var feature: SystemExtensionTourAlert.Feature {
            switch self {
            case .plutonium: .splitTunneling
            case .wireGuard: .wireguard
            }
        }
    }

    // MARK: - Telemetry

    /// Reports one activation request to telemetry: the attempt, the approval tour, and the outcome.
    final class SystemExtensionActivationTelemetry {
        /// What the system found installed when it asked whether to replace it.
        enum InstalledCopy {
            /// An older version, which the request replaces.
            case replacedOlderVersion
            /// The same version, which a user-initiated request replaces anyway to show the approval flow again.
            case reinstalled(isEnabled: Bool)
            /// The same or a newer version, which the request keeps.
            case kept(isEnabled: Bool)
        }

        enum Prompt: Equatable {
            case displayed
            case answered(SystemExtensionEvent.PromptOutcome)
        }

        let origin: SystemExtensionEvent.Origin
        let extensionType: SystemExtensionEvent.ExtensionType
        /// The connection protocol when the request was made.
        let connectionProtocol: ConnectionProtocol
        var installedCopy: InstalledCopy?

        private let submittedAt: Date
        private var isAwaitingApproval = false
        /// Where the approval tour stands. A cancelled tour also reports the request as declined, so its later
        /// outcome is not reported again.
        private var prompt: Prompt?
        private var hasReportedOutcome = false

        @Dependency(\.telemetryService) private var telemetryService
        @Dependency(\.date.now) private var now

        init(
            origin: SystemExtensionEvent.Origin,
            extensionType: SystemExtensionEvent.ExtensionType,
            connectionProtocol: ConnectionProtocol
        ) {
            @Dependency(\.date.now) var submissionDate
            self.origin = origin
            self.extensionType = extensionType
            self.connectionProtocol = connectionProtocol
            self.submittedAt = submissionDate
        }

        func reportAttempt() {
            send([.installAttempt(origin: origin, extensionType: extensionType)])
        }

        func record(_ state: SystemExtensionRequest.State) {
            if case .userActionRequired = state {
                isAwaitingApproval = true
            }
            // A user who approves the extension while the tour is open went to System Settings without its button.
            let promptReport: SystemExtensionEvent.Report? = if case .succeeded = state {
                movePrompt(to: .answered(.proceeded))
            } else {
                nil
            }
            let result = Self.outcome(for: state, installedCopy: installedCopy).flatMap(recordResult)
            send([promptReport, result].compactMap { $0 })
        }

        /// Moves the approval tour to `next` and reports it, when the request waits for approval.
        func reportPrompt(_ next: Prompt) {
            let promptReport = movePrompt(to: next)
            // sysextd keeps a request open until the user approves it, so closing the tour is the only sign of a
            // refusal.
            let result = promptReport != nil && next == .answered(.cancelled) ? recordResult(.userDeclined) : nil
            send([promptReport, result].compactMap { $0 })
        }

        /// The outcome a state ends the request with, or nil if the request has not ended or reports nothing.
        static func outcome(
            for state: SystemExtensionRequest.State,
            installedCopy: InstalledCopy?
        ) -> SystemExtensionEvent.InstallOutcome? {
            switch state {
            case .succeeded:
                switch installedCopy {
                case nil:
                    .installed
                case .replacedOlderVersion:
                    .upgraded
                case let .reinstalled(isEnabled), let .kept(isEnabled):
                    .alreadyThere(isExtensionActive: isEnabled)
                }
            case .cancelled:
                // The app cancels a request when the installed copy is the same or newer.
                if case let .kept(isEnabled) = installedCopy {
                    .alreadyThere(isExtensionActive: isEnabled)
                } else {
                    .alreadyThere(isExtensionActive: nil)
                }
            case let .failed(error):
                .failed(SystemExtensionEvent.ErrorCode(error))
            case .replacing, .userActionRequired, .superseded:
                nil
            }
        }

        /// Moves the tour to `next` and returns its report, or nil when the tour cannot get there from where it
        /// stands. Only a shown tour can be answered, and the app skips a tour only when it never shows it.
        private func movePrompt(to next: Prompt) -> SystemExtensionEvent.Report? {
            let current: Prompt? = switch next {
            case .displayed, .answered(.skipped): nil
            case .answered(.proceeded), .answered(.cancelled): .displayed
            }
            guard isAwaitingApproval, prompt == current else { return nil }
            prompt = next
            return switch next {
            case .displayed:
                .approvalPromptDisplay(origin: origin, extensionType: extensionType)
            case let .answered(outcome):
                .approvalPromptAction(origin: origin, extensionType: extensionType, outcome: outcome)
            }
        }

        /// Records the outcome and returns its report, or nil when one was already reported.
        private func recordResult(_ outcome: SystemExtensionEvent.InstallOutcome) -> SystemExtensionEvent.Report? {
            guard !hasReportedOutcome else { return nil }
            hasReportedOutcome = true
            return .installResult(
                origin: origin,
                extensionType: extensionType,
                outcome: outcome,
                connectionProtocol: connectionProtocol,
                timeToResult: now.timeIntervalSince(submittedAt)
            )
        }

        private func send(_ reports: [SystemExtensionEvent.Report]) {
            guard !reports.isEmpty else { return }
            Task { [telemetryService] in
                for report in reports {
                    // The scheduler throws when the user has not opted in to usage data, which is expected.
                    try? await telemetryService.systemExtensionEvent(report)
                }
            }
        }
    }

    extension SystemExtensionEvent.ExtensionType {
        init(_ type: SystemExtensionType) {
            switch type {
            case .wireGuard: self = .wireGuard
            case .plutonium: self = .splitTunnel
            }
        }
    }

    extension SystemExtensionEvent.ErrorCode {
        /// Maps an activation error to its `charCode`. Errors from outside the system extension framework are sent
        /// as unknown.
        init(_ error: Error) {
            // `debugDescription` spells a `FourCharCode` as its four characters.
            let charCode = (error as? OSSystemExtensionError)?.code.charCode.debugDescription
            self = charCode.flatMap(Self.init(rawValue:)) ?? .unknown
        }
    }

#endif
