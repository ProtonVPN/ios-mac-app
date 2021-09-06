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
    var isNextButtonVisible: Bool { get }
    var isPrevButtonVisible: Bool { get }
    var steps: [SystemExtensionGuideViewModel.Step] { get }
    var step: (Int, SystemExtensionGuideViewModel.Step) { get }
    /// Callback to allow window to close itself after all sysexes are installed
    var isTimeToClose: SystemExtensionTourAlert.CloseConditionCallback { get set }
}

class SystemExtensionGuideViewModel: NSObject {
 
    struct Step {
        let title: String
        let description: String
        let imageName: String
    }
    
    let steps: [Step] = [
        Step(title: LocalizedString.sysexWizardStep1Title, description: LocalizedString.sysexWizardStep1Description, imageName: "1-step"),
        Step(title: LocalizedString.sysexWizardStep2Title, description: LocalizedString.sysexWizardStep2Description, imageName: "2-step"),
        Step(title: LocalizedString.sysexWizardStep3Title, description: LocalizedString.sysexWizardStep3Description, imageName: "3-step"),
        Step(title: LocalizedString.sysexWizardStep4Title, description: LocalizedString.sysexWizardStep4Description, imageName: "4-step"),
        Step(title: LocalizedString.sysexWizardStep5Title, description: LocalizedString.sysexWizardStep5Description, imageName: "5-step"),
    ]
    private var currentStep = 0
    
    weak var viewController: SystemExtensionGuideVCProtocol?
    var acceptedHandler: () -> Void
    var isTimeToClose: SystemExtensionTourAlert.CloseConditionCallback
    
    init(isTimeToClose: @escaping SystemExtensionTourAlert.CloseConditionCallback, acceptedHandler: @escaping () -> Void) {
        self.isTimeToClose = isTimeToClose
        self.acceptedHandler = acceptedHandler
    }
    
    // MARK: - Private
    
    private func updateView() {
        viewController?.render()
    }
    
    @objc private func closeSelfIfNeeded() {
        isTimeToClose { [weak self] itsTime in
            if itsTime {
                DispatchQueue.main.async {
                    self?.viewController?.closeSelf()
                }
            }
        }
    }
}

// MARK: - SystemExtensionGuideViewModelProtocol

extension SystemExtensionGuideViewModel: SystemExtensionGuideViewModelProtocol {
    
    func viewWillAppear() {
        // Autoclose this window after installation finishes
        NotificationCenter.default.addObserver(self, selector: #selector(closeSelfIfNeeded), name: SystemExtensionManagerNotification.installationSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(closeSelfIfNeeded), name: SystemExtensionManagerNotification.installationError, object: nil)
        
        currentStep = 0
        updateView()
    }
    
    func didTapNext() {
        currentStep = min(currentStep + 1, steps.count - 1)
        viewController?.render()
    }
    
    func didTapPrevious() {
        currentStep = max(currentStep - 1, 0)
        viewController?.render()
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
