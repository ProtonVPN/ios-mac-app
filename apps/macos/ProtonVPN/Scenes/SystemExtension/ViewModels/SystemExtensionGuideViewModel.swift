//
//  SystemExtensionGuideViewModel.swift
//  ProtonVPN - Created on 31/12/20.
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

import Cocoa
import vpncore

protocol SystemExtensionGuideViewModelProtocol: NSObject {
    func didTapNext()
    func didTapPrevious()
    func didTapAccept()
    func viewWillAppear()
    func tourCancelled()

    var extensionsCount: Int { get set }
    var finishedTour: Bool { get }
    var isNextButtonVisible: Bool { get }
    var isPrevButtonVisible: Bool { get }
    var steps: [SystemExtensionGuideViewModel.Step] { get }
    var step: (Int, SystemExtensionGuideViewModel.Step) { get }
    /// Callback to allow window to close itself after all sysexes are installed
    var close: (() -> Void)? { get set }
    var contentChanged: (() -> Void)? { get set }
}

class SystemExtensionGuideViewModel: NSObject {
    static let securityPreferencesUrlString = "x-apple.systempreferences:com.apple.preference.security"

    struct Step {
        let title: String
        let description: String
        let imageName: String
    }
    
    var steps: [Step] { return extensionsCount == 1 ? stepsOne : stepsMany }
    
    private let stepsOne: [Step] = [
        Step(title: LocalizedString.sysexWizardStep1Title1, description: LocalizedString.sysexWizardStep1Description1, imageName: "1-step-1"),
        Step(title: LocalizedString.sysexWizardStep2Title, description: LocalizedString.sysexWizardStep2Description, imageName: "2-step"),
        Step(title: LocalizedString.sysexWizardStep3Title, description: LocalizedString.sysexWizardStep3Description, imageName: "3-step"),
        Step(title: LocalizedString.sysexWizardStep4Title1, description: LocalizedString.sysexWizardStep4Description1, imageName: "4-step-1"),
    ]
    private let stepsMany: [Step] = [
        Step(title: LocalizedString.sysexWizardStep1Title, description: LocalizedString.sysexWizardStep1Description, imageName: "1-step"),
        Step(title: LocalizedString.sysexWizardStep2Title, description: LocalizedString.sysexWizardStep2Description, imageName: "2-step"),
        Step(title: LocalizedString.sysexWizardStep3Title, description: LocalizedString.sysexWizardStep3Description, imageName: "3-step"),
        Step(title: LocalizedString.sysexWizardStep4Title, description: LocalizedString.sysexWizardStep4Description, imageName: "4-step"),
        Step(title: LocalizedString.sysexWizardStep5Title, description: LocalizedString.sysexWizardStep5Description, imageName: "5-step"),
    ]
    private var currentStep = 0
    
    private let alertService: CoreAlertService
    private let propertiesManager: PropertiesManagerProtocol
    var finishedTour = false
    var extensionsCount: Int
    var acceptedHandler: () -> Void
    var cancelledHandler: () -> Void

    var contentChanged: (() -> Void)?
    var close: (() -> Void)?
    
    init(extensionsCount: Int, alertService: CoreAlertService, propertiesManager: PropertiesManagerProtocol, acceptedHandler: @escaping () -> Void, cancelledHandler: @escaping () -> Void) {
        self.alertService = alertService
        self.extensionsCount = extensionsCount
        self.acceptedHandler = acceptedHandler
        self.cancelledHandler = cancelledHandler
        self.propertiesManager = propertiesManager
    }
    
    // MARK: - Private
    
    private func updateView() {
        contentChanged?()
    }
    
    private func finish(_ notification: Notification) {
        guard let request = notification.object as? SystemExtensionRequest, request.userInitiated else {
            return
        }

        finishedTour = true
        alertService.push(alert: SysexEnabledAlert())
        close?()
    }

    private func userTriedToSupersedeRequest(_ notification: Notification) {
        SafariService.openLink(url: Self.securityPreferencesUrlString)
        didTapNext()
    }
}

// MARK: - SystemExtensionGuideViewModelProtocol

extension SystemExtensionGuideViewModel: SystemExtensionGuideViewModelProtocol {
    
    func viewWillAppear() {
        // Autoclose this window after installation finishes
        NotificationCenter.default.addObserver(forName: SystemExtensionManagerNotification.allExtensionsInstalled, object: nil, queue: nil, using: finish)
        NotificationCenter.default.addObserver(forName: SystemExtensionsStateCheck.userAlreadyRequestedExtension, object: nil, queue: nil, using: userTriedToSupersedeRequest)
        
        currentStep = 0
        updateView()
    }

    func tourCancelled() {
        cancelledHandler()
    }
    
    func didTapNext() {
        currentStep = min(currentStep + 1, steps.count - 1)
        contentChanged?()
    }
    
    func didTapPrevious() {
        currentStep = max(currentStep - 1, 0)
        contentChanged?()
    }
    
    func didTapAccept() {
        acceptedHandler()
    }
    
    var isNextButtonVisible: Bool {
        return currentStep < steps.count - 1
    }
    
    var isPrevButtonVisible: Bool {
        return currentStep > 0
    }
    
    var step: (Int, Step) {
        return (currentStep, steps[currentStep])
    }
}
