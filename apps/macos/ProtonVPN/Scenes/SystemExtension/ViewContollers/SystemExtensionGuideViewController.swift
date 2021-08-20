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
    func render()
    func closeSelf()
}

final class SystemExtensionGuideViewController: NSViewController {
        
    @IBOutlet private weak var confirmationButton: PrimaryActionButton!
    
    @IBOutlet private weak var titleView: NSTextField!
    @IBOutlet private weak var subtitleView: NSTextField!
    
    @IBOutlet private weak var step1title: NSTextField!
    @IBOutlet private weak var step2title: NSTextField!
    @IBOutlet private weak var step3title: NSTextField!
    @IBOutlet private weak var step4title: NSTextField!
    @IBOutlet private weak var step5title: NSTextField!
    @IBOutlet private weak var textUnderSteps: NSTextField!
    
    @IBOutlet private weak var step1number: NSView!
    @IBOutlet private weak var step2number: NSView!
    @IBOutlet private weak var step3number: NSView!
    @IBOutlet private weak var step4number: NSView!
    @IBOutlet private weak var step5number: NSView!
    
    @IBOutlet private weak var nextBtn: NSButton!
    @IBOutlet private weak var previousBtn: NSButton!
    
    @IBOutlet private weak var imageView: NSImageView!
    @IBOutlet private weak var imageDescription: NSTextField!
    
    private lazy var titles: [NSTextField] = [step1title, step2title, step3title, step4title, step5title]
    private lazy var numbers: [NSView] = [step1number, step2number, step3number, step4number, step5number]
    private let images = ["1-step", "2-step", "3-step", "4-step", "5-step"]
    
    var viewModel: SystemExtensionGuideViewModelProtocol!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance(withTitle: LocalizedString.sysexWizardWindowTitle)
        viewModel.viewWillAppear()
    }
    
    private func setupViews() {
        titleView.stringValue = LocalizedString.sysexWizardTitle
        subtitleView.stringValue = LocalizedString.sysexWizardSubtitle
        confirmationButton.title = LocalizedString.sysexWizardButton
        confirmationButton.actionType = .confirmative
        confirmationButton.isEnabled = true
        
        for (index, step) in viewModel.steps.enumerated() {
            titles[index].stringValue = step.title
            titles[index].textColor = NSColor.protonWhite()
            (numbers[index].subviews.first as? NSTextField)?.textColor = NSColor.protonWhite()
            numbers[index].wantsLayer = true
            numbers[index].layer?.backgroundColor = NSColor.protonLightGrey().cgColor
            numbers[index].layer?.cornerRadius = numbers[index].bounds.width / 2
        }
        textUnderSteps.stringValue = LocalizedString.sysexWizardTextUnderSteps
        textUnderSteps.textColor = NSColor.protonGreyUnselectedWhite()
        imageDescription.stringValue = ""
    }
    
    // MARK: - Actions
    
    @IBAction func nextAction(_ sender: Any) {
        viewModel?.didTapNext()
    }
    
    @IBAction func previousAction(_ sender: Any) {
        viewModel?.didTapPrevious()
    }
    
    @IBAction func confirmButtonAction(_ sender: Any) {
        viewModel?.didTapAccept()
    }
    
}

// MARK: - SystemExtensionGuideVCProtocol

extension SystemExtensionGuideViewController: SystemExtensionGuideVCProtocol {
    
    func render() {
        // Making buttons invisible throug alpha so other views won't move as in case with changing isHidden
        nextBtn.alphaValue = viewModel.isNextButtonVisible ? 1.0 : 0.0
        previousBtn.alphaValue = viewModel.isPrevButtonVisible ? 1.0 : 0.0
        
        let fontSize: CGFloat = 14
        let (curentIndex, step) = viewModel.step
        
        for (index, field) in titles.enumerated() {
            field.font = index == curentIndex
                ? NSFont.boldSystemFont(ofSize: fontSize)
                : NSFont.systemFont(ofSize: fontSize)
            field.superview?.alphaValue = index == curentIndex ? 1.0 : 0.3
        }
        
        imageView.image = NSImage(named: step.imageName)
        imageDescription.stringValue = step.description
        
    }
    
    func closeSelf() {
        dismiss(nil)
    }
    
}
