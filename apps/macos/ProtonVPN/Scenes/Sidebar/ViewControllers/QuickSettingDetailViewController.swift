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
import LegacyCommon
import Modals_macOS
import SwiftUI
import LocalFeatureFlags
import Theme
import Home
import Home_macOS
import Strings

protocol QuickSettingsDetailViewControllerProtocol: AnyObject {
    var arrowIV: NSImageView! { get }
    var arrowHorizontalConstraint: NSLayoutConstraint! { get }
    var contentBox: NSBox! { get }
    var dropdownTitle: NSTextField! { get }
    var dropdownDescription: NSTextField! { get }
    var dropdownLearnMore: InteractiveActionButton! { get }
    var dropdownUpgradeButton: PrimaryActionButton! { get }
    var dropdownBusinessUpsell: NSImageView! { get }
    var dropdownNote: NSTextField! { get }

    func reloadOptions()
    func updateNetshieldStats()
}

class QuickSettingDetailViewController: NSViewController, QuickSettingsDetailViewControllerProtocol {
    
    @IBOutlet weak var arrowIV: NSImageView!
    @IBOutlet weak var arrowHorizontalConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var contentBox: NSBox!
    
    @IBOutlet weak var dropdownTitle: NSTextField!
    @IBOutlet weak var dropdownDescription: NSTextField!
    @IBOutlet weak var dropdownLearnMore: InteractiveActionButton!
    @IBOutlet weak var dropdownUpgradeButton: PrimaryActionButton!
    @IBOutlet weak var dropdownBusinessUpsell: NSImageView!
    @IBOutlet weak var dropdownNote: NSTextField!
    
    @IBOutlet weak var dropdownOptionsView: NSView!
    
    @IBOutlet var noteTopConstraint: NSLayoutConstraint!
    @IBOutlet var upgradeTopConstraint: NSLayoutConstraint!
    @IBOutlet var upgradeBottomConstraint: NSLayoutConstraint!

    @IBOutlet var netShieldStatsContainer: NSView! {
        didSet {
            let netShieldPresenter = presenter as? NetshieldDropdownPresenter
            guard let netShieldPresenter, netShieldPresenter.isNetShieldStatsEnabled else {
                netShieldStatsContainer?.removeFromSuperview()
                return
            }
            setupNetShieldStatsContainer(presenter: netShieldPresenter)
        }
    }
    
    let presenter: QuickSettingDropdownPresenterProtocol

    var netShieldStatsView = NSHostingView(rootView: NetShieldStatsView())
    
    init(_ presenter: QuickSettingDropdownPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: QuickSettingDetailViewController.className(), bundle: nil)
        self.presenter.viewController = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupNetShieldStatsContainer(presenter: NetshieldDropdownPresenter) {
        netShieldStatsView.translatesAutoresizingMaskIntoConstraints = false
        netShieldStatsContainer.addSubview(netShieldStatsView)
        netShieldStatsContainer.topAnchor.constraint(equalTo: netShieldStatsView.topAnchor).isActive = true
        netShieldStatsContainer.bottomAnchor.constraint(equalTo: netShieldStatsView.bottomAnchor).isActive = true
        netShieldStatsContainer.leadingAnchor.constraint(equalTo: netShieldStatsView.leadingAnchor).isActive = true
        netShieldStatsContainer.trailingAnchor.constraint(equalTo: netShieldStatsView.trailingAnchor).isActive = true
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
        
        dropdownTitle.setAccessibilityIdentifier("QSTitle")
        dropdownDescription.setAccessibilityIdentifier("QSDescription")
        dropdownUpgradeButton.setAccessibilityIdentifier("UpgradeButton")
        dropdownLearnMore.setAccessibilityIdentifier("LearnMoreButton")
        dropdownNote.setAccessibilityIdentifier("QSNote")
        
        view.wantsLayer = true
        view.layer?.masksToBounds = false

        let shadow = NSShadow()
        shadow.shadowColor = .color(.background)
        shadow.shadowBlurRadius = 8
        view.shadow = shadow
        view.layer?.shadowRadius = 5

        contentBox.borderColor = .color(.border, .weak)
        contentBox.borderWidth = 1
        contentBox.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        contentBox.fillColor = .color(.background)

        arrowIV.cell?.setAccessibilityElement(false)
        
        dropdownUpgradeButton.title = Localizable.upgrade
        dropdownUpgradeButton.actionType = .confirmative
        dropdownUpgradeButton.fontSize = .paragraph

        dropdownBusinessUpsell.image = Theme.Asset.icVpnBusinessBadge.image
        dropdownBusinessUpsell.isHidden = true
        dropdownBusinessUpsell.toolTip = Localizable.availableWithVpnBusinessTooltip

        dropdownLearnMore.fontSize = .small
        dropdownLearnMore.title = Localizable.learnMore

        reloadOptions()
    }

    // MARK: - Utils

    func updateNetshieldStats() {
        if let model = (presenter as? NetshieldDropdownPresenter)?.netShieldViewModel {
            netShieldStatsView.rootView.viewModel = model
        }
    }

    func reloadOptions() {
        var needsUpgrade = false
        let views: [QuickSettingsDropdownOption] = presenter.options.enumerated().map { (index, presenter) in
            let thisNeedsUpgrade = presenter.requiresUpdate || presenter.requiresBusinessUpdate
            defer { needsUpgrade = thisNeedsUpgrade || needsUpgrade }

            let view: QuickSettingsDropdownOption? = QuickSettingsDropdownOption.loadViewFromNib()
            view?.titleLabel.stringValue = presenter.title
            view?.optionIconIV.image = presenter.icon
            if thisNeedsUpgrade {
                dropdownBusinessUpsell.isHidden = !presenter.requiresBusinessUpdate
                view?.blockedStyle(business: presenter.requiresBusinessUpdate)
                view?.action = { [weak self] in
                    presenter.selectCallback?()
                    self?.presenter.dismiss?()
                }
            } else {
                if presenter.active {
                    view?.selectedStyle()
                } else {
                    view?.disabledStyle()
                    view?.action = { [weak self] in
                        presenter.selectCallback?()
                        self?.presenter.dismiss?()
                    }
                }
            }
            return view!
        }
        
        self.upgradeTopConstraint.isActive = needsUpgrade
        self.upgradeBottomConstraint.isActive = needsUpgrade
        
        self.noteTopConstraint.isActive = self.dropdownNote.attributedStringValue.length > 0
        
        self.dropdownUpgradeButton.isHidden = !needsUpgrade
        self.dropdownOptionsView.subviews.forEach { $0.removeFromSuperview() }
        self.dropdownOptionsView.fillVertically(withViews: views)
        self.dropdownOptionsView.wantsLayer = true
        self.dropdownOptionsView.layer?.masksToBounds = false
    }
}
