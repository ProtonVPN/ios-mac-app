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
        & SystemExtensionsStateCheckFactory
    private let factory: Factory

    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var systemExtensionsStateCheck: SystemExtensionsStateCheck = factory.makeSystemExtensionsStateCheck()

    init(factory: SidebarViewModel.Factory) {
        self.factory = factory
    }

    func showSystemExtensionInstallAlert() {
        systemExtensionsStateCheck.startCheckAndInstallIfNeeded { result in
            if case .success(let resultType) = result, case .installed = resultType {
                PMLog.D("Turning on SmartProtocol for the first time")
                self.propertiesManager.smartProtocol = true
            }
        }
    }
    
}
