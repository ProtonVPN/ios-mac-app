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
    @IBOutlet private weak var imageDescription: PVPNTextViewLink!
    
    private lazy var titles: [NSTextField] = [step1title, step2title, step3title, step4title, step5title]
    private lazy var numbers: [NSView] = [step1number, step2number, step3number, step4number, step5number]
    
    var viewModel: SystemExtensionGuideViewModelProtocol
    weak var windowService: WindowService?

    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: SystemExtensionGuideViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name(String(describing: Self.self)), bundle: nil)
        
        viewModel.contentChanged = { [weak self] in
            self?.render()
        }
        viewModel.close = { [weak self] in
            self?.closeSelf()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance(withTitle: LocalizedString.sysexWizardWindowTitle)
        viewModel.viewWillAppear()
    }

    func userWillCloseWindow() {
        if !viewModel.finishedTour {
            viewModel.tourCancelled()
        }
    }
    
    private func setupViews() {
        titleView.stringValue = LocalizedString.sysexWizardTitle
        subtitleView.stringValue = LocalizedString.sysexWizardSubtitle
        confirmationButton.title = LocalizedString.sysexWizardButton
        confirmationButton.actionType = .confirmative
        confirmationButton.isEnabled = true
        
        let steps = viewModel.steps        
        for index in titles.indices {
            guard index < steps.count else {
                titles[index].isHidden = true
                numbers[index].isHidden = true
                continue
            }
            let step = steps[index]
            titles[index].stringValue = step.title
            titles[index].textColor = .color(.text)
            (numbers[index].subviews.first as? NSTextField)?.textColor = .color(.text)
            numbers[index].wantsLayer = true
            numbers[index].layer?.backgroundColor = .cgColor(.background, .strong)
            numbers[index].layer?.cornerRadius = numbers[index].bounds.width / 2
            titles[index].isHidden = false
            numbers[index].isHidden = false
        }
        
        textUnderSteps.stringValue = LocalizedString.sysexWizardTextUnderSteps
        textUnderSteps.textColor = .color(.text, .weak)
        imageDescription.defaultStyle.alignment = .center
        imageDescription.textViewFont = NSFont.boldSystemFont(ofSize: 14.0)
        imageDescription.textStorage?.setAttributedString(NSAttributedString(string: ""))
        
        nextBtn.wantsLayer = true
        CABasicAnimation.addPulseAnimation(nextBtn.layer)
        
    }
    
    // MARK: - Actions
    
    @IBAction func nextAction(_ sender: Any) {
        viewModel.didTapNext()
        nextBtn.layer?.removeAllAnimations()
    }
    
    @IBAction func previousAction(_ sender: Any) {
        viewModel.didTapPrevious()
    }
    
    @IBAction func confirmButtonAction(_ sender: Any) {
        viewModel.didTapAccept()
    }
    
    // MARK: - ViewModel callbacks
    
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
        imageDescription.hyperLink(originalText: step.description, hyperLink: LocalizedString.sysexWizardStep1DescriptionLink, urlString: SystemExtensionGuideViewModel.securityPreferencesUrlString)
    }
    
    func closeSelf() {
        view.window?.close()
    }
    
}

extension SystemExtensionGuideViewController: WindowControllerDelegate {
    func windowCloseRequested(_ sender: WindowController) {
        windowService?.windowCloseRequested(sender)
    }

    func windowWillClose(_ sender: WindowController) {
        self.userWillCloseWindow()
        windowService?.windowWillClose(sender)
    }
}
