//
//  QuickSettingDetailViewController.swift
//  ProtonVPN - Created on 09/11/2020.
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

protocol QuickSettingsDetailViewControllerProtocol: class {
    var arrowIV: NSImageView! { get }
    var arrowHorizontalConstraint: NSLayoutConstraint! { get }
    var contentBox: NSBox! { get }
    var dropdownTitle: NSTextField! { get }
    var dropdownDescription: NSTextField! { get }
    var dropdownLearnMore: NSButton! { get }
    var dropdownUgradeButton: PrimaryActionButton! { get }
    var dropdownNote: NSTextField! { get }
    
    func reloadOptions()
}

class QuickSettingDetailViewController: NSViewController, QuickSettingsDetailViewControllerProtocol {
    
    @IBOutlet weak var arrowIV: NSImageView!
    @IBOutlet weak var arrowHorizontalConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var contentBox: NSBox!
    
    @IBOutlet weak var dropdownTitle: NSTextField!
    @IBOutlet weak var dropdownDescription: NSTextField!
    @IBOutlet weak var dropdownLearnMore: NSButton!
    @IBOutlet weak var dropdownUgradeButton: PrimaryActionButton!
    @IBOutlet weak var dropdownNote: NSTextField!
    
    @IBOutlet weak var dropdownOptionsView: NSView!
    
    @IBOutlet var noteTopConstraint: NSLayoutConstraint!
    @IBOutlet var upgradeTopConstraint: NSLayoutConstraint!
    @IBOutlet var upgradeBottomConstraint: NSLayoutConstraint!
    
    let presenter: QuickSettingDropdownPresenterProtocol
    
    init( _ presenter: QuickSettingDropdownPresenterProtocol ) {
        self.presenter = presenter
        super.init(nibName: QuickSettingDetailViewController.className(), bundle: nil)
        self.presenter.viewController = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
        
        view.wantsLayer = true
        
        let shadow = NSShadow()
        shadow.shadowColor = .protonDarkGrey()
        shadow.shadowBlurRadius = 8
        view.shadow = shadow
        view.layer?.masksToBounds = false
        view.layer?.shadowRadius = 5
        
        dropdownUgradeButton.attributedTitle = LocalizedString.qsGetPlus.attributed(withColor: .white, fontSize: 12)
        
        dropdownLearnMore.attributedTitle = LocalizedString.learnMore.attributed(
            withColor: .protonGreen(),
            fontSize: 12,
            alignment: .left
        )
        reloadOptions()
    }
        
    // MARK: - Utils
    
    func reloadOptions() {
        var needsUpgrade = false
        let views: [QuickSettingsDropdownOption] = presenter.options.enumerated().map { (index, presenter) in
            needsUpgrade = needsUpgrade || presenter.requiresUpdate
            let view: QuickSettingsDropdownOption? = QuickSettingsDropdownOption.loadViewFromNib()
            view?.titleLabel.stringValue = presenter.title
            view?.optionIconIV.image = presenter.icon
            view?.selectedColor = presenter.selectedColor
            if presenter.requiresUpdate {
                view?.blockedStyle()
                view?.action = {
                    presenter.selectCallback?()
                }
            } else {
                if presenter.active {
                    view?.selectedStyle()
                } else {
                    view?.disabledStyle()
                    view?.action = {
                        presenter.selectCallback?()
                    }
                }
            }
            return view!
        }
        
        self.upgradeTopConstraint.isActive = needsUpgrade
        self.upgradeBottomConstraint.isActive = needsUpgrade
        
        self.noteTopConstraint.isActive = self.dropdownNote.attributedStringValue.length > 0
        
        self.dropdownUgradeButton.isHidden = !needsUpgrade
        self.dropdownOptionsView.subviews.forEach { $0.removeFromSuperview() }
        self.dropdownOptionsView.fillVertically(withViews: views)
        self.dropdownOptionsView.wantsLayer = true
        self.dropdownOptionsView.layer?.masksToBounds = false
    }
}
