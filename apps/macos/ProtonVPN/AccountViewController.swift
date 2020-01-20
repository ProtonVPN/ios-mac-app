//
//  AccountViewController.swift
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

class AccountViewController: NSViewController {

    @IBOutlet weak var usernameLabel: PVPNTextField!
    @IBOutlet weak var usernameValue: PVPNTextField!
    @IBOutlet weak var usernameSeparator: NSBox!
    
    @IBOutlet weak var accountTypeLabel: PVPNTextField!
    @IBOutlet weak var accountTypeValue: PVPNTextField!
    @IBOutlet weak var accountTypeSeparator: NSBox!
    
    @IBOutlet weak var accountPlanLabel: PVPNTextField!
    @IBOutlet weak var accountPlanValue: PVPNTextField!
    @IBOutlet weak var accountPlanSeparator: NSBox!
    
    @IBOutlet weak var manageSubscriptionButton: GreenActionButton!
    
    private let viewModel = AccountViewModel(vpnKeychain: VpnKeychain())
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init() {
        super.init(nibName: NSNib.Name("Account"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupStackView()
        setupFooterView()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.protonGrey().cgColor
    }
    
    private func setupStackView() {
        usernameLabel.attributedStringValue = LocalizedString.username.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        usernameValue.attributedStringValue = viewModel.username.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .right)
        usernameSeparator.fillColor = .protonLightGrey()
        
        accountTypeLabel.attributedStringValue = LocalizedString.accountType.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        accountTypeValue.attributedStringValue = viewModel.accountType.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .right)
        accountTypeSeparator.fillColor = .protonLightGrey()
        
        accountPlanLabel.attributedStringValue = LocalizedString.accountPlan.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        accountPlanSeparator.fillColor = .protonLightGrey()
        
        if let accountPlan = viewModel.accountPlan {
            let planColor = colorForAccount(accountPlan)
            accountPlanValue.attributedStringValue = accountPlan.description.attributed(withColor: planColor, fontSize: 16, alignment: .right)
        } else {
            accountPlanValue.attributedStringValue = LocalizedString.unavailable.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .right)
        }
    }
    
    private func setupFooterView() {
        manageSubscriptionButton.title = LocalizedString.manageSubscription
        manageSubscriptionButton.target = self
        manageSubscriptionButton.action = #selector(manageSubscriptionButtonAction)
    }
    
    private func colorForAccount(_ plan: AccountPlan) -> NSColor {
        return plan.colorForUI
    }
    
    @objc private func manageSubscriptionButtonAction() {
        viewModel.manageSubscriptionAction()
    }
}
