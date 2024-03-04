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

public protocol SystemExtensionManagerFactory {
    func makeSystemExtensionManager() -> SystemExtensionManager
}

public enum SystemExtensionType: String, CaseIterable {
    case openVPN = "ch.protonvpn.mac.OpenVPN-Extension"
    case wireGuard = "ch.protonvpn.mac.WireGuard-Extension"

    public var machServiceName: String {
        let teamId = Bundle.main.infoDictionary!["TeamIdentifierPrefix"] as! String
        return "\(teamId)group.\(rawValue)"
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
    public static let allExtensionsInstalled = Notification.Name("SystemExtensionsAllInstalled")
    public static let userCancelledTour = Notification.Name("UserCancelledSystemExtensionTour")

    static let requestQueue = DispatchQueue(label: "ch.proton.sysex.requests")

    public typealias Factory = CoreAlertServiceFactory &
                                PropertiesManagerFactory &
                                VpnKeychainFactory &
                                ProfileManagerFactory
    private let factory: Factory

    private typealias InstallationState = [SystemExtensionType: SystemExtensionRequest.State]

    private func reduce(installationResults: InstallationState, didRequireUserApproval: Bool) -> SystemExtensionResult {
        return installationResults.reduce(into: .success(.alreadyThere)) { (accumulator, sysexInstallationResult) in
            if case .failure = accumulator { return }
            let (type, installationResult) = sysexInstallationResult
            switch installationResult {
            case .cancelled, .superseded:
                break
            case .succeeded:
                accumulator = .success(didRequireUserApproval ? .installed : .upgraded)
            case .failed(let error):
                accumulator = .failure(.installationError(internalError: error))
            default:
                log.assertionFailure("\(type.rawValue) had unexpected final state \(installationResult)")
            }
        }
    }

    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    fileprivate lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()

    fileprivate var outstandingRequests: Set<SystemExtensionRequest> = []

    private var userIsLoggedIn: Bool {
        vpnKeychain.userIsLoggedIn
    }

    public init(factory: Factory) {
        self.factory = factory
    }

    internal func request(_ request: SystemExtensionRequest) {
        log.info("Submitting request \(request.request.description) for \(request.request.identifier)")

        outstandingRequests.insert(request)
        OSSystemExtensionManager.shared.submitRequest(request.request)
    }

    /// Synchronously (!) uninstall all extensions on the system, with an optional timeout.
    public func uninstallAll(userInitiated: Bool, timeout: DispatchTime? = nil) -> DispatchTimeoutResult {
        let group = DispatchGroup()

        SystemExtensionType.allCases.forEach { type in
            group.enter()
            request(.uninstall(type: type, manager: self) { stateChange in
                switch stateChange {
                case .succeeded, .failed:
                    group.leave()
                default:
                    log.error("Unexpected state transition for uninstall: \(stateChange)")
                }
            })
        }

        guard let timeout = timeout else {
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
    private func submitInstallationRequests(userActionRequiredHandler: @escaping ((Int) -> Void),
                                            installationFinishedHandler: @escaping ((InstallationState) -> Void)) {
        let queue = DispatchQueue(label: "ch.protonvpn.sysext.status.\(UUID().uuidString)")
        var states: InstallationState = [:]
        var extensionsRequiringApproval = 0

        let finishedInstalling = DispatchGroup()
        let installStatesKnown = DispatchGroup()

        SystemExtensionType.allCases.forEach { type in
            finishedInstalling.enter()
            installStatesKnown.enter()

            let install = SystemExtensionRequest.install(type: type, manager: self) { stateChange in
                var prevState: SystemExtensionRequest.State?
                queue.sync {
                    prevState = states[type]
                    states[type] = stateChange
                }

                switch stateChange {
                case .replacing:
                    break
                case .userActionRequired:
                    queue.sync { extensionsRequiringApproval += 1 }
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
            request(install)
        }

        installStatesKnown.notify(queue: SystemExtensionManager.requestQueue) {
            guard extensionsRequiringApproval > 0 else { return }

            userActionRequiredHandler(extensionsRequiringApproval)
        }

        finishedInstalling.notify(queue: SystemExtensionManager.requestQueue) {
            installationFinishedHandler(states)
        }
    }

    /// Installs all extensions, provided the following hold true:
    /// - The user is logged in
    /// - The default connection protocol requires a system extension, OR
    /// - The user has created a custom profile containing a protocol requiring a system extension
    ///
    /// - Parameters:
    ///   - shouldStartTour: Whether the system extension tour should be shown if user approval is required. When false,
    ///   and approval is required, actionHandler will report `.failure(.tourSkipped)`.
    ///   - actionHandler: A completion handler invoked when installation or system extension tour complete or fail.
    public func checkAndInstallOrUpdateExtensionsIfNeeded(shouldStartTour: Bool,
                                                          actionHandler: @escaping (SystemExtensionResult) -> Void) {
        // do not check if the user is not logged in to avoid showing the installation prompt on the
        // login screen on first start
        guard userIsLoggedIn else {
            log.debug("Aborted sysex installation because user is not logged in", category: .sysex)
            return
        }

        guard propertiesManager.connectionProtocol.requiresSystemExtension ||
              profileManager.customProfiles.contains(where: { $0.connectionProtocol.requiresSystemExtension }) else {
            log.debug("Aborted sysex installation because it is not required by profiles and settings", category: .sysex)
            return
        }

        installOrUpdateExtensionsIfNeeded(shouldStartTour: shouldStartTour, actionHandler: actionHandler)
    }

    /// Installs all extensions. This will result in system extension dialogs appearing if the user has
    /// not approved any on the system yet.
    ///
    /// - Parameters:
    ///   - shouldStartTour: Whether the system extension tour should be shown if user approval is required. When false,
    ///   and approval is required, actionHandler will report `.failure(.tourSkipped)`.
    ///   - actionHandler: A completion handler invoked when installation or system extension tour complete or fail.
    public func installOrUpdateExtensionsIfNeeded(shouldStartTour: Bool,
                                                  actionHandler: @escaping (SystemExtensionResult) -> Void) {
        var didRequireUserApproval = false

        submitInstallationRequests(userActionRequiredHandler: { [unowned self] _ in
            didRequireUserApproval = true

            guard shouldStartTour else {
                actionHandler(.failure(.tourSkipped))
                return
            }

            let tour = SystemExtensionTourAlert(cancelHandler: {
                DispatchQueue.main.async {
                    actionHandler(.failure(.tourCancelled))
                    NotificationCenter.default.post(name: Self.userCancelledTour, object: nil)
                }
            })

            self.alertService.push(alert: tour)
        }, installationFinishedHandler: { installationResults in
            let result = self.reduce(installationResults: installationResults, didRequireUserApproval: didRequireUserApproval)
            log.debug("Finished installation with result: \(result)", category: .sysex)

            DispatchQueue.main.async {
                actionHandler(result)
                if case .success(.installed) = result {
                    NotificationCenter.default.post(name: Self.allExtensionsInstalled, object: didRequireUserApproval)
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
    typealias StateChangeCallback = ((State) -> Void)

    let action: Action
    let request: OSSystemExtensionRequest
    let stateChangeCallback: StateChangeCallback
    unowned let manager: SystemExtensionManager

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
        existing < newExtension || manager.propertiesManager.forceExtensionUpgrade
    }

    required init(action: Action,
                  request: OSSystemExtensionRequest,
                  stateChange: @escaping StateChangeCallback,
                  manager: SystemExtensionManager) {
        self.action = action
        self.request = request
        self.stateChangeCallback = stateChange
        self.manager = manager
    }

    static func install(type: SystemExtensionType,
                        manager: SystemExtensionManager,
                        stateChange: @escaping StateChangeCallback) -> Self {
        let result = Self(action: .install,
                          request: .activationRequest(forExtensionWithIdentifier: type.rawValue,
                                                      queue: SystemExtensionManager.requestQueue),
                          stateChange: stateChange,
                          manager: manager)
        result.request.delegate = result
        return result
    }

    static func uninstall(type: SystemExtensionType,
                          manager: SystemExtensionManager,
                          stateChange: @escaping StateChangeCallback) -> Self {
        let result = Self(action: .uninstall,
                          request: .deactivationRequest(forExtensionWithIdentifier: type.rawValue,
                                                        queue: SystemExtensionManager.requestQueue),
                          stateChange: stateChange,
                          manager: manager)
        result.request.delegate = result
        return result
    }

    deinit {
        log.debug("Deinit request \(uuid.uuidString) for \(request.identifier)")
    }
}

extension SystemExtensionRequest: OSSystemExtensionRequestDelegate {
    public func request(_ request: OSSystemExtensionRequest,
                        actionForReplacingExtension existing: OSSystemExtensionProperties,
                        withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        assert(existing.bundleIdentifier == ext.bundleIdentifier,
               "Extensions have mismatched identifiers? (\(existing.bundleIdentifier) and \(ext.bundleIdentifier))")

        let shouldReplace = shouldExtension(.init(version: existing.bundleShortVersion,
                                                  build: existing.bundleVersion,
                                                  bundleId: existing.bundleIdentifier),
                                            beReplacedBy: .init(version: ext.bundleShortVersion,
                                                                build: ext.bundleVersion,
                                                                bundleId: ext.bundleIdentifier))

        // Don't call stateChangeCallback(.cancelled) here, we do that when sysextd calls us again
        // with `request(_:didFailWithError:)`.
        guard shouldReplace else { return .cancel }

        stateChangeCallback(.replacing)
        return .replace
    }

    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        stateChangeCallback(.userActionRequired)
    }

    public func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        guard let sysextError = error as? OSSystemExtensionError else {
            stateChangeCallback(.failed(error))
            return
        }

        switch sysextError.code {
        case .requestCanceled:
            stateChangeCallback(.cancelled)
        case .requestSuperseded:
            stateChangeCallback(.superseded)
        default:
            stateChangeCallback(.failed(sysextError))
        }

        manager.outstandingRequests.remove(self)
    }

    public func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        stateChangeCallback(.succeeded(result))

        manager.outstandingRequests.remove(self)
    }
}
#endif
