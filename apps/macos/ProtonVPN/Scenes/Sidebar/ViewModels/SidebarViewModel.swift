//
//  SidebarViewModel.swift
//  ProtonVPN - Created on 27.06.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
import vpncore

final class SidebarViewModel {
    typealias Factory = PropertiesManagerFactory
        & CoreAlertServiceFactory
        & SystemExtensionManagerFactory
    private let factory: Factory

    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var systemExtensionManager: SystemExtensionManager = factory.makeSystemExtensionManager()

    init(factory: SidebarViewModel.Factory) {
        self.factory = factory
    }

    func showSystemExtensionInstallAlert() {
        guard !propertiesManager.openVPNExtensionTourDisplayed else {
            return
        }

        // just show once
        propertiesManager.openVPNExtensionTourDisplayed = true

        let alert = SysexInstallationRequiredAlert(continueHandler: { [weak self] in
            // try to install
            self?.systemExtensionManager.requestExtensionInstall(completion: { [weak self] result in
                if case .success = result {
                    self?.propertiesManager.smartProtocol = true
                }
            })
            // and show the user instructions
            self?.alertService.push(alert: SystemExtensionTourAlert())
        })
        alertService.push(alert: alert)
    }
}
