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
    func viewDidAppear()
}

class SystemExtensionGuideViewModel: NSObject, SystemExtensionGuideViewModelProtocol {
    
    weak var viewController: SystemExtensionGuideVCProtocol?
    
    private var currentView = 0
    
    func viewDidAppear() {
        currentView = 0
        updateView()
    }
    
    func didTapNext() {
        currentView += 1
        updateView()
    }
    
    func didTapPrevious() {
        currentView -= 1
        updateView()
    }
    
    // MARK: - Private
    
    private func updateView() {
        switch currentView {
        case 0:
            viewController?.displayStep1()
            viewController?.descriptionText = "1. " + LocalizedString.openVPNSettingsStep1
        case 1:
            viewController?.displayStep2()
            viewController?.descriptionText = "2. " + LocalizedString.openVPNSettingsStep2
        default:
            viewController?.displayStep3()
            viewController?.descriptionText = "3. " + LocalizedString.openVPNSettingsStep3
        }
    }
}
