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
    @IBOutlet weak var popupMessageLabel: NSTextField!
    @IBOutlet weak var popupURLLabel: NSTextField!
    @IBOutlet weak var instructionIV: NSImageView!
    
    let utilUrl = "https://support.apple.com/kb/DL1998"
    
    var alert: KillSwitchRequiresSwift5Alert?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tryConnectButton.title = LocalizedString.killSwitchEnableAgain
        keepDisabledButton.title = LocalizedString.killSwitchKeepDisabled
        
        let description = (alert?.message ?? "").attributed(withColor: .white, fontSize: 14, alignment: .natural)
        popupMessageLabel.attributedStringValue = description
        popupURLLabel.attributedStringValue = utilUrl.attributed(withColor: .protonGreen(), fontSize: 14, alignment: .natural)

        let gestureURL = NSClickGestureRecognizer(target: self, action: #selector(didTapUrl))
        popupURLLabel.addGestureRecognizer(gestureURL)
        
        let gestureIV = NSClickGestureRecognizer(target: self, action: #selector(didTapUrl))
        instructionIV.addGestureRecognizer(gestureIV)
    }
   
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyWarningAppearance(withTitle: LocalizedString.protonVpnMacOS)
    }
    
    // MARK: - Actions
    
    @objc fileprivate func didTapUrl() {
        let url = URL(string: self.utilUrl)
        NSWorkspace.shared.open(url!)
    }
    
    @IBAction func didTapTryConnect(_ sender: Any) {
        alert?.actions.forEach({ action in
            action.handler?()
        })
        dismiss(nil)
    }
    
    @IBAction func didTapKeepDisabled(_ sender: Any) {
        alert?.dismiss?()
        dismiss(nil)
    }
}
