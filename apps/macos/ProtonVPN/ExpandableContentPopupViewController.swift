//
//  ExpandableContentPopupViewController.swift
//  ProtonVPN - Created on 21/09/2020.
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

class ExpandableContentPopupViewController: NSViewController {
    
    let viewModel: ExpandablePopupViewModel
    
    @IBOutlet weak var actionBtn: WhiteCancelationButton!
    @IBOutlet weak var contentView: NSView!
    @IBOutlet weak var footerView: NSView!
    @IBOutlet weak var popupImage: NSImageView!
    @IBOutlet weak var headerLbl: NSTextField!
    @IBOutlet weak var expandableLbl: NSTextField!
    @IBOutlet weak var footerLbl: NSTextField!
    @IBOutlet weak var displayMoreBtn: GreenActionButton!
    
    private var enabler = true
    
    required init(viewModel: ExpandablePopupViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("ExpandableContentPopup"), bundle: nil)
        viewModel.dismissViewController = { [weak self] in
            DispatchQueue.main.async {
                self?.dismiss(nil)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        actionBtn.title = viewModel.actionButtonTitle
        actionBtn.action = #selector(didPressActionBtn)
        actionBtn.target = self
        popupImage.image = #imageLiteral(resourceName: "temp")
        headerLbl.stringValue = viewModel.title
        footerLbl.stringValue = viewModel.extraInfo
        expandableLbl.stringValue = viewModel.hiddenInfo
        expandableLbl.textColor = .protonLightGrey()
        contentView.wantsLayer = true
        footerView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.protonGreyShade().cgColor
        footerView.layer?.backgroundColor = NSColor.protonGreyShade().cgColor
        
        displayMoreBtn.title = LocalizedString.moreInfo + "  "
        displayMoreBtn.target = self
        displayMoreBtn.action = #selector(expandBtnTap)
        
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    // MARK: - Private
    @objc private func didPressActionBtn() {
        viewModel.action()
    }
    
    @objc private func expandBtnTap() {
        enabler = !enabler
        displayMoreBtn.title = (enabler ? LocalizedString.lessInfo : LocalizedString.moreInfo) + "  "
        displayMoreBtn.image = enabler ? #imageLiteral(resourceName: "arrow-up") : #imageLiteral(resourceName: "arrow-down")
    }
    
    fileprivate func displayMessage( _ hide: Bool ) {
//        NSAnimationContext.runAnimationGroup({ context in
//            context.duration = 1
//            self.contentHeightConstraint.animator().constant = hide ? 120 : 250
//        }) {
//            self.contentHeightConstraint.animator().constant = hide ? 250 : 120
//        }
    }
}
