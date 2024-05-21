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
import LegacyCommon
import Ergonomics
import Theme
import Strings

final class AccountViewController: NSViewController {

    @IBOutlet private weak var usernameLabel: PVPNTextField!
    @IBOutlet private weak var usernameValue: PVPNTextField!
    @IBOutlet private weak var usernameSeparator: NSBox!
    
    @IBOutlet private weak var accountPlanLabel: PVPNTextField!
    @IBOutlet private weak var accountPlanValue: PVPNTextField!
    @IBOutlet private weak var accountPlanSeparator: NSBox!
    
    @IBOutlet private weak var manageSubscriptionButton: InteractiveActionButton!
    
    private let viewModel: AccountViewModel
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(accountViewModel: AccountViewModel) {
        viewModel = accountViewModel
        super.init(nibName: NSNib.Name("Account"), bundle: nil)

        viewModel.reloadNeeded = { [weak self] in
            self?.setupData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupActions()
        setupData()
    }

    private func setupUI() {
        view.wantsLayer = true
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background, .weak)
        }
        setupStackView()
        setupFooterView()
    }
    
    private func setupStackView() {
        usernameLabel.attributedStringValue = Localizable.username.styled(font: .themeFont(.heading4), alignment: .left)
        usernameValue.attributedStringValue = viewModel.username.styled(.weak, font: .themeFont(.heading4), alignment: .right)
        usernameSeparator.fillColor = .color(.border, .weak)
        
        accountPlanLabel.attributedStringValue = Localizable.accountPlan.styled(font: .themeFont(.heading4), alignment: .left)
        accountPlanSeparator.fillColor = .color(.border, .weak)
        
        if let planTitle = viewModel.planTitle {
            accountPlanValue.attributedStringValue = planTitle.styled(AppTheme.Style(viewModel.maxTier),
                                                                      font: .themeFont(.heading4),
                                                                      alignment: .right)
        } else {
            accountPlanValue.attributedStringValue = Localizable.unavailable.styled(.weak, 
                                                                                    font: .themeFont(.heading4),
                                                                                    alignment: .right)
        }
    }
    
    private func setupFooterView() {
        manageSubscriptionButton.title = Localizable.manageSubscription
        manageSubscriptionButton.target = self
        manageSubscriptionButton.action = #selector(manageSubscriptionButtonAction)

        manageSubscriptionButton.title = Localizable.manageSubscription
    }

    private func setupActions() {
        manageSubscriptionButton.target = self
        manageSubscriptionButton.action = #selector(manageSubscriptionButtonAction)

    }
    
    private func setupData() {
        usernameValue.attributedStringValue = viewModel.username.styled(.weak, font: .themeFont(.heading4), alignment: .right)

        if let planTitle = viewModel.planTitle {
            accountPlanValue.attributedStringValue = planTitle.styled(AppTheme.Style(viewModel.maxTier),
                                                                      font: .themeFont(.heading4),
                                                                      alignment: .right)
        } else {
            accountPlanValue.attributedStringValue = Localizable.unavailable.styled(.weak, 
                                                                                    font: .themeFont(.heading4),
                                                                                    alignment: .right)
        }
    }
    
    @objc private func manageSubscriptionButtonAction() {
        viewModel.manageSubscriptionAction()
    }
}
