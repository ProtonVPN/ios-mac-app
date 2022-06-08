//
//  SystemExtensionStateCheck.swift
//  ProtonVPN-mac
//
//  Created by Jaroslav Oo on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore

protocol SystemExtensionsStateCheckFactory {
    func makeSystemExtensionsStateCheck() -> SystemExtensionsStateCheck
}

extension DependencyContainer: SystemExtensionsStateCheckFactory {
    func makeSystemExtensionsStateCheck() -> SystemExtensionsStateCheck {
        return SystemExtensionsStateCheck(systemExtensionManager: makeSystemExtensionManager(), alertService: makeCoreAlertService(), propertiesManager: makePropertiesManager(), vpnKeychain: makeVpnKeychain())
    }
}

class SystemExtensionsStateCheck {
    public static let userAlreadyRequestedExtension = Notification.Name("UserAlreadyRequestedExtension")

    enum SuccessResultType {
        case nothing
        case installed // At least one sysex had to be installed
        case updated   // At least one sysex had to be updated, and NONE had to be installed
    }

    public struct UserCancelledInstall: Error, CustomStringConvertible {
        public let description = "The install was cancelled by the user."
    }
    
    private let systemExtensionManager: SystemExtensionManager
    private let alertService: CoreAlertService
    private let propertiesManager: PropertiesManagerProtocol
    private let vpnKeychain: VpnKeychainProtocol
    
    init(systemExtensionManager: SystemExtensionManager, alertService: CoreAlertService, propertiesManager: PropertiesManagerProtocol, vpnKeychain: VpnKeychainProtocol) {
        self.systemExtensionManager = systemExtensionManager
        self.alertService = alertService
        self.propertiesManager = propertiesManager
        self.vpnKeychain = vpnKeychain
    }

    // swiftlint:disable function_body_length
    /// Caller beware: `actionHandler` can be called twice here: once if the user cancels the sysext flow, and
    /// a second time if the user then decides to go to system preferences and enable manually.
    func startCheckAndInstallIfNeeded(userInitiated: Bool, actionHandler: @escaping (Result<SuccessResultType, Error>) -> Void) {
        log.debug("Checking status of system extensions...", category: .sysex)

        systemExtensionManager.extensionStatuses { statuses in
            var updateWasNeeded = false
            var installNeeded = [SystemExtensionType]()
            statuses.forEach { type, status in
                switch status {
                case .notInstalled:
                    log.info("SysEx \(type) is not installed", category: .sysex)
                    installNeeded.append(type)
                    
                case .outdated:
                    log.info("SysEx \(type) is outdated. Requesting install update.", category: .sysex)
                    updateWasNeeded = true
                    self.systemExtensionManager.request(.install(type: type, userInitiated: userInitiated, completion: { _ in }))
                    
                case .ok:
                    log.info("SysEx \(type) is up to date", category: .sysex)
                }
            }
            
            guard !installNeeded.isEmpty else {
                log.debug("No initial install needed, bailing.", category: .sysex)
                actionHandler(.success(updateWasNeeded ? .updated : .nothing))
                return
            }
            
            guard !self.propertiesManager.sysexSuccessWasShown else {
                log.debug("Already showed Sysex success, bailing.", category: .sysex)
                return // Dirty workaround for a problem where after restart macos doesn't want to give us XPC connection on the first try and app thinks sysex is not yet installed.
            }
            
            self.alertService.push(alert: SystemExtensionTourAlert(extensionsCount: installNeeded.count, continueHandler: {
                DispatchQueue.global(qos: .userInitiated).async {
                    let dispatchGroup = DispatchGroup()
                    var errors = [Error]()

                    installNeeded.forEach { type in
                        dispatchGroup.enter()
                        log.debug("Requesting sysex install for \(type.rawValue)", category: .sysex)

                        self.systemExtensionManager.request(.install(type: type, userInitiated: userInitiated, completion: { result in
                            switch result {
                            case .success:
                                break

                            case .failure(let error):
                                errors.append(error)
                            }
                            dispatchGroup.leave()
                        }))
                    }

                    dispatchGroup.wait()
                    guard errors.isEmpty else {
                        log.debug("Encountered errors in sysex install: \(String(describing: errors))", category: .sysex)

                        // Don't pop an alert if the user tries to spam sysex install. Instead post a notification so the
                        // sysex view can take more informative action.
                        guard !errors.contains(where: { $0 is SystemExtensionRequest.RequestAlreadyWaitingError }) else {
                            if userInitiated {
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(name: SystemExtensionsStateCheck.userAlreadyRequestedExtension, object: nil)
                                }
                            }
                            return
                        }

                        self.alertService.push(alert: SysexInstallingErrorAlert())
                        actionHandler(.failure(errors.first!))
                        return
                    }
                    actionHandler(.success(.installed))
                }
            }, cancelHandler: {
                // Note: This doesn't display an error to the user as above, as the user is probably aware
                // that they closed the window.
                log.debug("User cancelled system extension install", category: .sysex)
                actionHandler(.failure(UserCancelledInstall()))
            }))
        }
    }

    func checkSystemExtensionRequiredAndInstallIfNeeded() {
        // do not check if the user is not logged in to avoid showing the installation prompt on the login screen on first start
        guard (try? vpnKeychain.fetch()) != nil else {
            return
        }

        // only install the extension if OpenVPN/WireGuard is selected or Smart Protocol is enabled
        let needsInstallExtension: Bool = {
            switch propertiesManager.connectionProtocol {
            case .smartProtocol:
                return true
            case let .vpnProtocol(vpnProtocol):
                switch vpnProtocol {
                case .ike:
                    return false
                case .wireGuard, .openVpn:
                    return true
                }
            }
        }()

        guard needsInstallExtension else {
            log.debug("No need to install system extension (protocol is \(propertiesManager.connectionProtocol.description)), bailing.", category: .sysex)
            return
        }

        log.debug("Checking system extensions because \(self.propertiesManager.connectionProtocol) is set as default protocol")

        startCheckAndInstallIfNeeded(userInitiated: false) { result in
            switch result {
            case .success:
                log.debug("System extensions are OK, keeping \(self.propertiesManager.connectionProtocol) as default protocol", category: .app)
            case let .failure(error):
                log.error("Checking system extensions failed with \(error). Switching default protocol to IKEv2", category: .app)
                self.propertiesManager.vpnProtocol = .ike
                self.propertiesManager.smartProtocol = false
            }
        }
    }
}
