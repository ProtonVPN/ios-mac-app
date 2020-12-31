//
//  SystemExtensionGuideViewController.swift
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

public protocol SystemExtensionGuideVCProtocol {
    func displayStep1()
    func displayStep2()
    func displayStep3()
}

class SystemExtensionGuideViewController: NSViewController, SystemExtensionGuideVCProtocol {
    
    @IBOutlet weak var bodyView: NSView!
    @IBOutlet weak var footerView: NSView!
    @IBOutlet weak var confirmationButton: PrimaryActionButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBody()
        setupFooter()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance(withTitle: LocalizedString.openVPNSettingsTitle)
    }
    
    private func setupBody() {
        bodyView.wantsLayer = true
        bodyView.layer?.backgroundColor = NSColor.protonGrey().cgColor
    }
    
    private func setupFooter() {
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = NSColor.protonGreyShade().cgColor
        confirmationButton.title = LocalizedString.gotIt
        confirmationButton.fontSize = 14
    }
    
    @IBAction func confirmButtonAction(_ sender: Any) {
        dismiss(nil)
    }
    
    // MARK: - SystemExtensionGuideVCProtocol
    
    func displayStep1() {
        
    }
    
    func displayStep2() {
        
    }
    
    func displayStep3() {
        
    }
}
