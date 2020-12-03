//
//  PopUpViewController.swift
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

class PopUpViewController: NSViewController {
    
    @IBOutlet weak var bodyView: NSView!
    @IBOutlet weak var popUpIcon: NSImageView!
    @IBOutlet weak var popUpDescription: NSTextField!
    @IBOutlet var popUpDescriptionTextView: NSTextView!
    @IBOutlet weak var leadingDescriptionConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var footerView: NSView!
    @IBOutlet weak var cancelButton: WhiteCancelationButton!
    @IBOutlet weak var confirmButton: PrimaryActionButton!
    
    let viewModel: PopUpViewModel
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: PopUpViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("PopUp"), bundle: nil)
        
        viewModel.dismissViewController = { [weak self] in
            DispatchQueue.main.async {
                self?.dismiss(nil)
            }
        }
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
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        viewModel.updateInterface = { [unowned self] in
            self.setupBodySection()
            self.setupFooterSection()
        }
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        viewModel.cleanUp()
    }
    
    private func setupBodySection() {
        bodyView.wantsLayer = true
        bodyView.layer?.backgroundColor = NSColor.protonGrey().cgColor
        
        popUpIcon.image = #imageLiteral(resourceName: "temp")
        if !viewModel.showIcon {
            popUpIcon.isHidden = true
            leadingDescriptionConstraint.constant = 20
        }
        
        // HACK: Because the text view is inside a scroll view, it doesn't correctly. To address this, the text view is aligned to the text field, which forces the resizing of the dialog.
        popUpDescription.attributedStringValue = viewModel.attributedDescription
        
        popUpDescriptionTextView.backgroundColor = .protonGreyShade()
        popUpDescriptionTextView.delegate = viewModel
        
        popUpDescriptionTextView.textStorage?.setAttributedString(viewModel.attributedDescription)
    }
    
    private func setupFooterSection() {
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = NSColor.protonGreyShade().cgColor
        
        if let cancelTitle = viewModel.cancelButtonTitle {
            cancelButton.title = cancelTitle
            cancelButton.fontSize = 14
            cancelButton.target = self
            cancelButton.action = #selector(cancelButtonAction)
        } else {
            cancelButton.isHidden = true
        }
        
        confirmButton.title = viewModel.confirmButtonTitle
        confirmButton.fontSize = 14
        confirmButton.actionType = viewModel.confirmationType
        confirmButton.target = self
        confirmButton.action = #selector(confirmButtonAction)
    }
    
    @objc private func cancelButtonAction() {
        viewModel.cancel()
        dismiss(nil)
    }
    
    @objc private func confirmButtonAction() {
        viewModel.confirm()
        dismiss(nil)
    }
}

// MARK: - Equatable
extension PopUpViewController {
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? PopUpViewController else {
            return false
        }
        
        return viewModel == other.viewModel
    }
}
