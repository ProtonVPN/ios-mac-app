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
    func viewWillAppear()
    func tourCancelled()

    var finishedTour: Bool { get }
    /// Callback to allow window to close itself after all sysexes are installed
    var close: (() -> Void)? { get set }
    var contentChanged: (() -> Void)? { get set }
}

class SystemExtensionGuideViewModel: NSObject {

    var finishedTour = false
    let userWasShownTourBefore: Bool
    var cancelledHandler: () -> Void

    var contentChanged: (() -> Void)?
    var close: (() -> Void)?
    
    init(userWasShownTourBefore: Bool,
         cancelledHandler: @escaping () -> Void) {
        self.userWasShownTourBefore = userWasShownTourBefore
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

        updateView()
    }

    func tourCancelled() {
        cancelledHandler()
    }
}
