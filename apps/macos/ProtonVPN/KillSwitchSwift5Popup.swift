//
//  KillSwitchSwift5Popup.swift
//  ProtonVPN - Created on 22/05/2020.
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

class KillSwitchSwift5Popup: NSViewController {

    @IBOutlet weak var tryConnectButton: PrimaryActionButton!
    @IBOutlet weak var keepDisabledButton: WhiteCancelationButton!
    @IBOutlet weak var popupMessageLabel: PVPNTextViewLink!
    @IBOutlet weak var instructionIV: NSImageView!
    @IBOutlet weak var dontAskButton: NSButton!

    let utilUrl = "https://support.apple.com/kb/DL1998"
    
    var alert: KillSwitchRequiresSwift5Alert?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let alert = alert else { return }
        
        tryConnectButton.title = alert.actions[alert.doneActionIndex].title
        keepDisabledButton.title = alert.actions[alert.cancelActionIndex].title
        
        dontAskButton.isHidden = !alert.dontShowCheckbox
        dontAskButton.title = LocalizedString.killSwitchDontAsk
        dontAskButton.state = .off
        
        let message = alert.message ?? ""
        let description = String(format: message, LocalizedString.killSwitchSwift5LibraryName)
        popupMessageLabel.hyperLink(originalText: description, hyperLink: LocalizedString.killSwitchSwift5LibraryName, urlString: utilUrl)
        
        let gestureIV = NSClickGestureRecognizer(target: self, action: #selector(didTapUrl))
        instructionIV.addGestureRecognizer(gestureIV)
    }
   
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyWarningAppearance(withTitle: LocalizedString.protonVpnMacOS)
    }
    
    // MARK: - Actions
    
    @objc fileprivate func didTapUrl() {
        guard let url = URL(string: self.utilUrl) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func didTapTryConnect(_ sender: Any) {
        guard let alert = alert else { return }
        
        alert.confirmHandler(dontAskButton.state == .on)
        dismiss(nil)
    }
    
    @IBAction func didTapKeepDisabled(_ sender: Any) {
        alert?.dismiss?()
        dismiss(nil)
    }
}
