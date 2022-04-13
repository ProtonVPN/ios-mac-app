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

final class AccountViewController: NSViewController {

    @IBOutlet private weak var usernameLabel: PVPNTextField!
    @IBOutlet private weak var usernameValue: PVPNTextField!
    @IBOutlet private weak var usernameSeparator: NSBox!
    
    @IBOutlet private weak var accountTypeLabel: PVPNTextField!
    @IBOutlet private weak var accountTypeValue: PVPNTextField!
    @IBOutlet private weak var accountTypeSeparator: NSBox!
    
    @IBOutlet private weak var accountPlanLabel: PVPNTextField!
    @IBOutlet private weak var accountPlanValue: PVPNTextField!
    @IBOutlet private weak var accountPlanSeparator: NSBox!
    
    @IBOutlet private weak var manageSubscriptionButton: GreenActionButton!
    @IBOutlet private weak var useCouponButton: GreenActionButton!

    private let viewModel: AccountViewModel
    private let couponViewController: CouponViewController
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(accountViewModel: AccountViewModel, couponViewModel: CouponViewModel) {
        viewModel = accountViewModel
        couponViewController = CouponViewController(viewModel: couponViewModel)
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
        view.layer?.backgroundColor = NSColor.protonGrey().cgColor

        usernameLabel.attributedStringValue = LocalizedString.username.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        usernameSeparator.fillColor = .protonLightGrey()

        accountTypeLabel.attributedStringValue = LocalizedString.accountType.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        accountPlanLabel.attributedStringValue = LocalizedString.accountPlan.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)

        accountTypeSeparator.fillColor = .protonLightGrey()
        accountPlanSeparator.fillColor = .protonLightGrey()

        manageSubscriptionButton.title = LocalizedString.manageSubscription
        useCouponButton.title = LocalizedString.useCoupon

        couponViewController.delegate = self
        couponViewController.viewWillAppear()
        couponViewController.view.isHidden = true
        view.addSubview(couponViewController.view)
        couponViewController.view.frame.size = NSSize(width: AppConstants.Windows.sidebarWidth, height: 200)
        couponViewController.view.frame.origin = .zero
        addChild(couponViewController)
    }

    private func setupActions() {
        manageSubscriptionButton.target = self
        manageSubscriptionButton.action = #selector(manageSubscriptionButtonAction)

        useCouponButton.target = self
        useCouponButton.action = #selector(useCoupon)
    }
    
    private func setupData() {
        usernameValue.attributedStringValue = viewModel.username.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .right)
        accountTypeValue.attributedStringValue = viewModel.accountType.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .right)

        if let accountPlan = viewModel.accountPlan {
            accountPlanValue.attributedStringValue = accountPlan.description.attributed(withColor: accountPlan.colorForUI, fontSize: 16, alignment: .right)
        } else {
            accountPlanValue.attributedStringValue = LocalizedString.unavailable.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .right)
        }

        useCouponButton.isHidden = !viewModel.canUsePromo
    }
    
    @objc private func manageSubscriptionButtonAction() {
        viewModel.manageSubscriptionAction()
    }

    @objc private func useCoupon() {
        couponViewController.view.frame.origin = CGPoint(x: (view.frame.size.width - AppConstants.Windows.sidebarWidth) / 2, y: 48)
        couponViewController.view.isHidden = false
    }
}

// MARK: CouponViewControllerDelegate
extension AccountViewController: CouponViewControllerDelegate {

    func userDidCloseCouponViewController() {
        couponViewController.view.isHidden = true
    }
}
