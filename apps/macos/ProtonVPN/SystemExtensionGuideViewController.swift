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

public protocol SystemExtensionGuideVCProtocol: NSViewController {
    
    var descriptionText: String? { get set }
    
    func displayStep1()
    func displayStep2()
    func displayStep3()
}

class SystemExtensionGuideViewController: NSViewController, SystemExtensionGuideVCProtocol {
        
    @IBOutlet weak var bodyView: NSView!
    @IBOutlet weak var footerView: NSView!
    @IBOutlet weak var confirmationButton: PrimaryActionButton!
    
    @IBOutlet weak var step1View: NSView!
    @IBOutlet weak var step2View: NSView!
    @IBOutlet weak var step3View: NSView!
    
    @IBOutlet weak var descriptionTF: NSTextField!
    
    @IBOutlet weak var nextBtn: NSButton!
    @IBOutlet weak var previousBtn: NSButton!
    
    @IBOutlet weak var indicator1Lbl: NSTextField!
    @IBOutlet weak var indicator2Lbl: NSTextField!
    @IBOutlet weak var indicator3Lbl: NSTextField!
    
    var viewModel: SystemExtensionGuideViewModelProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBody()
        setupFooter()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance(withTitle: LocalizedString.openVPNSettingsTitle)
        viewModel?.viewDidAppear()
    }
    
    private func setupBody() {
        bodyView.wantsLayer = true
        bodyView.layer?.backgroundColor = NSColor.protonGrey().cgColor
        [indicator1Lbl, indicator2Lbl, indicator3Lbl].forEach { indicator in
            indicator?.wantsLayer = true
            indicator?.layer?.borderWidth = 1
            indicator?.layer?.borderColor = .white
            indicator?.layer?.cornerRadius = 12
        }
    }
    
    private func setupFooter() {
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = NSColor.protonGreyShade().cgColor
        confirmationButton.title = LocalizedString.done
        confirmationButton.fontSize = 14
    }
    
    @IBAction func confirmButtonAction(_ sender: Any) {
        dismiss(nil)
    }
    
    // MARK: - Actions
    
    @IBAction func nextAction(_ sender: Any) {
        viewModel?.didTapNext()
    }
    
    @IBAction func previousAction(_ sender: Any) {
        viewModel?.didTapPrevious()
    }
    
    // MARK: - SystemExtensionGuideVCProtocol
    
    var descriptionText: String? {
        didSet {
            guard let descriptionText = descriptionText else { return }
            descriptionTF.attributedStringValue = descriptionText
                .attributed(withColor: .white, fontSize: 20)
        }
    }
    
    func displayStep1() {
        setVisible(true, false, false)
    }
    
    func displayStep2() {
        setVisible(false, true, false)
    }
    
    func displayStep3() {
        setVisible(false, false, true)
    }
    
    fileprivate func setVisible( _ step1: Bool, _ step2: Bool, _ step3: Bool) {
        step1View.isHidden = !step1
        step2View.isHidden = !step2
        step3View.isHidden = !step3
        
        indicator1Lbl.layer?.borderColor = step1 ? NSColor.protonGreen().cgColor : .white
        indicator1Lbl.textColor = step1 ? .protonGreen() : .white
        indicator2Lbl.layer?.borderColor = step2 ? NSColor.protonGreen().cgColor : .white
        indicator2Lbl.textColor = step2 ? .protonGreen() : .white
        indicator3Lbl.layer?.borderColor = step3 ? NSColor.protonGreen().cgColor : .white
        indicator3Lbl.textColor = step3 ? .protonGreen() : .white
        
        previousBtn.isHidden = step1
        nextBtn.isHidden = step3
        confirmationButton.isHidden = !step3
    }
}
