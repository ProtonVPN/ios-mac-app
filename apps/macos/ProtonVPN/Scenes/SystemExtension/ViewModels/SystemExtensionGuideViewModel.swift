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
    func viewWillAppear()
    func tourCancelled()

    var extensionsCount: Int { get }
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
        let image: Image
    }
    
    var steps: [Step] {
        var result = extensionsCount == 1 ? stepsOne : stepsMany
        // If the user was shown the tour before, tell the user to open System Preferences directly
        // since they won't see an alert with a link to open Security Preferences.
        if userWasShownTourBefore {
            let title = result[0].title
            result[0] = Step(title: title,
                             description: LocalizedString.sysexWizardStep1DescriptionGoToSystemPreferences,
                             image: Asset._1StepSecurityPrefs.image)
        }
        return result
    }
    
    private let stepsOne: [Step] = [
        Step(title: LocalizedString.sysexWizardStep1Title1, description: LocalizedString.sysexWizardStep1Description1, image: Asset._1Step1.image),
        Step(title: LocalizedString.sysexWizardStep2Title, description: LocalizedString.sysexWizardStep2Description, image: Asset._2Step.image),
        Step(title: LocalizedString.sysexWizardStep3Title, description: LocalizedString.sysexWizardStep3Description, image: Asset._3Step.image),
        Step(title: LocalizedString.sysexWizardStep4Title1, description: LocalizedString.sysexWizardStep4Description1, image: Asset._4Step1.image),
    ]
    private let stepsMany: [Step] = [
        Step(title: LocalizedString.sysexWizardStep1Title, description: LocalizedString.sysexWizardStep1Description, image: Asset._1Step.image),
        Step(title: LocalizedString.sysexWizardStep2Title, description: LocalizedString.sysexWizardStep2Description, image: Asset._2Step.image),
        Step(title: LocalizedString.sysexWizardStep3Title, description: LocalizedString.sysexWizardStep3Description, image: Asset._3Step.image),
        Step(title: LocalizedString.sysexWizardStep4Title, description: LocalizedString.sysexWizardStep4Description, image: Asset._4Step.image),
        Step(title: LocalizedString.sysexWizardStep5Title, description: LocalizedString.sysexWizardStep5Description, image: Asset._5Step.image),
    ]
    private var currentStep = 0
    
    private unowned let alertService: CoreAlertService
    private unowned let propertiesManager: PropertiesManagerProtocol

    var finishedTour = false
    let extensionsCount: Int
    let userWasShownTourBefore: Bool
    var cancelledHandler: () -> Void

    var contentChanged: (() -> Void)?
    var close: (() -> Void)?
    
    init(extensionsCount: Int,
         userWasShownTourBefore: Bool,
         alertService: CoreAlertService,
         propertiesManager: PropertiesManagerProtocol,
         cancelledHandler: @escaping () -> Void) {
        self.alertService = alertService
        self.extensionsCount = extensionsCount
        self.userWasShownTourBefore = userWasShownTourBefore
        self.propertiesManager = propertiesManager
        self.cancelledHandler = cancelledHandler
    }
    
    // MARK: - Private
    
    private func updateView() {
        contentChanged?()
    }
    
    private func finish(_ notification: Notification) {
        finishedTour = true
        close?()
    }
}

// MARK: - SystemExtensionGuideViewModelProtocol

extension SystemExtensionGuideViewModel: SystemExtensionGuideViewModelProtocol {
    func viewWillAppear() {
        // Autoclose this window after installation finishes
        NotificationCenter.default.addObserver(forName: SystemExtensionManager.allExtensionsInstalled, object: nil, queue: nil, using: finish)
        
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
