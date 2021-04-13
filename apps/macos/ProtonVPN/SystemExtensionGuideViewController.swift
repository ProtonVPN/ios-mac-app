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
    
    var descriptionText: NSAttributedString? { get set }
    
    func displayStep1()
    func displayStep2()
    func displayStep3()
    
    func closeSelf()
}

final class SystemExtensionGuideViewController: NSViewController, SystemExtensionGuideVCProtocol {
        
    @IBOutlet private weak var bodyView: NSView!
    @IBOutlet private weak var footerView: NSView!
    @IBOutlet private weak var confirmationButton: PrimaryActionButton!
    
    @IBOutlet private weak var step1View: NSView!
    @IBOutlet private weak var step2View: NSView!
    @IBOutlet private weak var step3View: NSView!
    
    @IBOutlet private weak var descriptionTF: NSTextField!
    private let textView = NSTextView() //  Used for links
    
    @IBOutlet private weak var nextBtn: NSButton!
    @IBOutlet private weak var previousBtn: NSButton!
    
    @IBOutlet private weak var indicator1Lbl: NSTextField!
    @IBOutlet private weak var indicator2Lbl: NSTextField!
    @IBOutlet private weak var indicator3Lbl: NSTextField!
    
    @IBOutlet private weak var step1ScreenshotVerticalConstraint: NSLayoutConstraint!
    @IBOutlet private weak var step1NumberVerticalConstraint: NSLayoutConstraint!
    @IBOutlet private weak var step1ScreenshotImageView: NSImageView!
    
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
        setupTextView()
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
    
    @objc func closeSelf() {
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
    
    var descriptionText: NSAttributedString? {
        didSet {
            guard let descriptionText = descriptionText else { return }
            descriptionTF.attributedStringValue = descriptionText
            textView.textStorage?.setAttributedString(descriptionText)
        }
    }
    
    func displayStep1() {
        if #available(macOS 11.0, *) {
            step1ScreenshotVerticalConstraint.constant = -30
            step1NumberVerticalConstraint.constant = -107
            step1ScreenshotImageView.image = NSImage(named: "open_extension_install_step1-11")

        } else { // macOS 10.15
            step1ScreenshotVerticalConstraint.constant = 0
            step1ScreenshotImageView.image = NSImage(named: "open_extension_install_step1")
            step1NumberVerticalConstraint.constant = -184
        }
        
        setVisible(true, false, false)
    }
    
    func displayStep2() {
        setVisible(false, true, false)
    }
    
    func displayStep3() {
        setVisible(false, false, true)
    }
    
    private func setVisible( _ step1: Bool, _ step2: Bool, _ step3: Bool) {
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
    
    // Let's add some magic to have a green colored link.
    private func setupTextView() {
        guard !textView.isDescendant(of: bodyView) else {
            return
        }
        
        textView.linkTextAttributes = [
            NSAttributedString.Key.foregroundColor: NSColor.protonGreen(),
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        
        textView.isEditable = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.backgroundColor = .clear
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        bodyView.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: descriptionTF.topAnchor, constant: 0),
            textView.bottomAnchor.constraint(equalTo: descriptionTF.bottomAnchor, constant: 0),
            textView.leadingAnchor.constraint(equalTo: descriptionTF.leadingAnchor, constant: -4), // This is magic padding that puts NSTextView's text at the same place as in connectionLabel.
            textView.trailingAnchor.constraint(equalTo: descriptionTF.trailingAnchor, constant: 4), // See above ^.
        ])
        
        descriptionTF.alphaValue = 0
    }
    
}
