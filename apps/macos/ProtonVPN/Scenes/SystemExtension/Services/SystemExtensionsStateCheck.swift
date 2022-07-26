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

    /// Caller beware: `actionHandler` can be called twice here: once if the user cancels the sysext flow, and
    /// a second time if the user then decides to go to system preferences and enable manually.
    func startCheckAndInstallIfNeeded(userInitiated: Bool, actionHandler: @escaping (Result<SuccessResultType, Error>) -> Void) {

    }

    func checkSystemExtensionRequiredAndInstallIfNeeded(userInitiated: Bool) {
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

        startCheckAndInstallIfNeeded(userInitiated: userInitiated) { result in
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
