//
//  PopUpViewModel.swift
//  ProtonVPN - Created on 27.06.19.
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
import vpncore

class PopUpViewModel: NSObject {
    
    let inAppLinkManager: InAppLinkManager?
    
    var title: String {
        // Don't show a title if the the description is using the alert's title
        if attributedDescription.string == alert.title {
            return ""
        } else {
            return alert.title ?? ""
        }
    }
    var confirmButtonTitle: String {
        return action(0)?.title ?? LocalizedString.ok
    }
    var confirmationType: PrimaryActionType {
        return action(0)?.style ?? .confirmative
    }
    var cancelButtonTitle: String? {
        return action(1)?.title
    }
    
    var attributedDescription: NSAttributedString
    var showIcon = true
    var updateInterface: (() -> Void)?
    var dismissViewController: (() -> Void)?
    var dismissCompletion: (() -> Void)?
    
    private var alert: SystemAlert
    private var onConfirm: (() -> Void)? {
        return action(0)?.handler
    }
    private var onCancel: (() -> Void)? {
        return action(1)?.handler
    }
    
    convenience init(alert: SystemAlert, inAppLinkManager: InAppLinkManager? = nil) {
        self.init(alert: alert,
                  attributedDescription: (alert.message ?? alert.title ?? LocalizedString.errorInternalError).attributed(withColor: .protonWhite(), fontSize: 14, alignment: .natural),
                  inAppLinkManager: inAppLinkManager)
    }
    
    init(alert: SystemAlert, attributedDescription: NSAttributedString, inAppLinkManager: InAppLinkManager? = nil) {
        self.alert = alert
        self.attributedDescription = attributedDescription
        self.inAppLinkManager = inAppLinkManager
    }
    
    func confirm() {
        onConfirm?()
    }
    
    func cancel() {
        onCancel?()
    }
    
    func close() {
        dismissViewController?()
    }
    
    func cleanUp() {
        dismissCompletion?()
    }
    
    private func action(_ index: Array<Any>.Index) -> AlertAction? {
        return alert.actions[optional: index]
    }
}

extension PopUpViewModel: NSTextViewDelegate {
    
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let link = link as? String, let inAppLinkManager = inAppLinkManager else { return true }
        
        do {
            try inAppLinkManager.openLink(link)
            close()
        } catch {
            PMLog.ET("Failed to open internal link: \(error)")
        }
        
        return true
    }
}

// MARK: - Equatable
extension PopUpViewModel {
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? PopUpViewModel else {
            return false
        }
        
        return title == other.title && attributedDescription.string == other.attributedDescription.string
    }
}
