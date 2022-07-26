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

import Foundation
import SystemExtensions
import vpncore

protocol SystemExtensionManagerFactory {
    func makeSystemExtensionManager() -> SystemExtensionManager
}

enum SystemExtensionType: String, CaseIterable {
    case openVPN = "ch.protonvpn.mac.OpenVPN-Extension"
    case wireGuard = "ch.protonvpn.mac.WireGuard-Extension"
    
    var machServiceName: String {
        let teamId = Bundle.main.infoDictionary!["TeamIdentifierPrefix"] as! String
        return "\(teamId)group.\(rawValue)"
    }
}

enum SystemExtensionResult {
    case installed
    case upgraded
    case nothing
    case failed(Error)
}

class SystemExtensionManager: NSObject {
    static let allExtensionsInstalled = Notification.Name("SystemExtensionsAllInstalled")
    static let requestQueue = DispatchQueue(label: "ch.proton.sysex.requests")

    typealias Factory = CoreAlertServiceFactory & PropertiesManagerFactory
    private typealias InstallationState = [SystemExtensionType: SystemExtensionRequest.State]

    private let alertService: CoreAlertService
    private let propertiesManager: PropertiesManagerProtocol

    init(factory: Factory) {
        self.alertService = factory.makeCoreAlertService()
        self.propertiesManager = factory.makePropertiesManager()
    }

    func request(_ request: SystemExtensionRequest) {
        log.info("Submitting request \(request.request.description) for \(request.request.identifier)")

        OSSystemExtensionManager.shared.submitRequest(request.request)
    }

    func uninstallAll(userInitiated: Bool, timeout: DispatchTime? = nil) -> DispatchTimeoutResult {
        let group = DispatchGroup()

        SystemExtensionType.allCases.forEach { type in
            group.enter()
            request(.uninstall(type: type) { stateChange in
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

    private func submitInstallationRequests(userInitiated: Bool,
                                            userActionRequiredHandler: @escaping ((Int) -> Void),
                                            installationFinishedHandler: @escaping ((InstallationState) -> Void)) {
        let queue = DispatchQueue(label: "ch.protonvpn.sysext.status.\(UUID().uuidString)")
        var states: InstallationState = [:]
        var extensionsRequiringApproval = 0

        let finishedInstalling = DispatchGroup()
        let installStatesKnown = DispatchGroup()

        SystemExtensionType.allCases.forEach { type in
            finishedInstalling.enter()
            installStatesKnown.enter()

            let install = SystemExtensionRequest.install(type: type) { stateChange in
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
                    if case .replacing = prevState {
                        // If we transition directly from the replacing state, that means that we didn't
                        // require user action to replace the extension, so it already exists on the system.
                        installStatesKnown.leave()
                    }
                    finishedInstalling.leave()
                }
            }
            request(install)
        }

        installStatesKnown.notify(queue: SystemExtensionManager.requestQueue) {
            userActionRequiredHandler(extensionsRequiringApproval)
        }

        finishedInstalling.notify(queue: SystemExtensionManager.requestQueue) {
            installationFinishedHandler(states)
        }
    }

    func checkAndInstallAllIfNeeded(userInitiated: Bool, actionHandler: @escaping (SystemExtensionResult) -> Void) {
        var didRequireUserApproval = false

        submitInstallationRequests(userInitiated: userInitiated,
            userActionRequiredHandler: { [unowned self] numberOfExtensionsToApprove in
            didRequireUserApproval = true

            self.alertService.push(alert: SystemExtensionTourAlert(extensionsCount: numberOfExtensionsToApprove,
                continueHandler: {
                // onetodo: this can go away
            }, cancelHandler: {
                // alsotodo: this can go away
            }))
        }, installationFinishedHandler: { installationResults in
            var result: SystemExtensionResult = .nothing

            for (type, finalState) in installationResults {
                switch finalState {
                case .cancelled, .superseded:
                    continue
                case .succeeded:
                    result = didRequireUserApproval ? .installed : .upgraded
                case .failed(let error):
                    result = .failed(error)
                default:
                    assertionFailure("\(type.rawValue) had unexpected final state \(finalState)")
                }

                if case .failed = result {
                    break
                }
            }

            guard case .nothing = result else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.allExtensionsInstalled, object: userInitiated)
                }
                return
            }
        })
    }
}

class SystemExtensionRequest: NSObject {
    typealias StateChangeCallback = ((State) -> Void)

    let request: OSSystemExtensionRequest
    let stateChangeCallback: StateChangeCallback

    let uuid = UUID()
    
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

    func shouldExtension(_ existing: ExtensionInfo, beReplacedBy newExtension: ExtensionInfo) -> Bool {
        existing < newExtension
    }

    required init(request: OSSystemExtensionRequest,
                  stateChange: @escaping StateChangeCallback) {
        self.request = request
        self.stateChangeCallback = stateChange
    }

    static func install(type: SystemExtensionType, stateChange: @escaping StateChangeCallback) -> Self {
        let result = Self(request: .activationRequest(forExtensionWithIdentifier: type.rawValue,
                                                      queue: SystemExtensionManager.requestQueue),
                          stateChange: stateChange)
        result.request.delegate = result
        return result
    }

    static func uninstall(type: SystemExtensionType, stateChange: @escaping StateChangeCallback) -> Self {
        let result = Self(request: .deactivationRequest(forExtensionWithIdentifier: type.rawValue,
                                                        queue: SystemExtensionManager.requestQueue),
                          stateChange: stateChange)
        result.request.delegate = result
        return result
    }
}

extension SystemExtensionRequest: OSSystemExtensionRequestDelegate {
    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        assert(existing.bundleIdentifier == ext.bundleIdentifier,
               "Extensions have mismatched identifiers? (\(existing.bundleIdentifier) and \(ext.bundleIdentifier))")

        return shouldExtension(.init(version: existing.bundleShortVersion,
                                     build: existing.bundleVersion,
                                     bundleId: existing.bundleIdentifier),
                               beReplacedBy: .init(version: ext.bundleShortVersion,
                                                   build: ext.bundleVersion,
                                                   bundleId: ext.bundleIdentifier)) ? .replace : .cancel
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        stateChangeCallback(.userActionRequired)
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
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
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        stateChangeCallback(.succeeded(result))
    }
}
