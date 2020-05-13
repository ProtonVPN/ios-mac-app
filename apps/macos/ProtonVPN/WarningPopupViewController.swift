//
//  WarningPopupViewController.swift
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

import Cocoa
import vpncore

class WarningPopupViewController: NSViewController {

    @IBOutlet weak var bodyView: NSView!
    @IBOutlet weak var warningImage: NSImageView!
    @IBOutlet weak var warningDescriptionLabel: NSTextField!
    @IBOutlet weak var wifiWarningScrollViewContainer: NSScrollView!
    @IBOutlet var wifiWarningDescription: PVPNTextViewLink!

    @IBOutlet weak var footerView: NSView!
    @IBOutlet weak var cancelButton: WhiteCancelationButton!
    @IBOutlet weak var continueButton: PrimaryActionButton!
    
    var viewModel: WarningPopupViewModel!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    required init(viewModel: WarningPopupViewModel) {
        super.init(nibName: NSNib.Name("WarningPopup"), bundle: nil)
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBodySection()
        setupFooterSection()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        view.window?.applyWarningAppearance(withTitle: viewModel.title)
    }
    
    private func setupBodySection() {
        wifiWarningScrollViewContainer.isHidden = true
        bodyView.wantsLayer = true
        bodyView.layer?.backgroundColor = NSColor.protonGrey().cgColor
        
        warningImage.image = viewModel.image
        warningDescriptionLabel.attributedStringValue = viewModel.description.attributed(withColor: .protonWhite(), fontSize: 14, alignment: .left)
    }
    
    private func setupFooterSection() {
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = NSColor.protonGreyShade().cgColor
        
        cancelButton.title = LocalizedString.cancel
        cancelButton.fontSize = 14
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonAction)
        
        continueButton.title = LocalizedString.continue
        continueButton.fontSize = 14
        continueButton.target = self
        continueButton.action = #selector(continueButtonAction)
    }
    
    @objc private func cancelButtonAction() {
        viewModel.onCancel?()
        dismiss(nil)
    }
    
    @objc private func continueButtonAction() {
        viewModel.onConfirm()
        dismiss(nil)
    }
}
