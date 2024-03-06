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
    @IBOutlet private weak var useCouponButton: InteractiveActionButton!
    private let couponViewController: CouponViewController
    private var banner: BannerView?
    
    private let viewModel: AccountViewModel
    
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
            accountPlanValue.attributedStringValue = planTitle.styled(viewModel.maxTier.styleForUI, font: .themeFont(.heading4), alignment: .right)
        } else {
            accountPlanValue.attributedStringValue = Localizable.unavailable.styled(.weak, font: .themeFont(.heading4), alignment: .right)
        }
    }
    
    private func setupFooterView() {
        manageSubscriptionButton.title = Localizable.manageSubscription
        manageSubscriptionButton.target = self
        manageSubscriptionButton.action = #selector(manageSubscriptionButtonAction)

        manageSubscriptionButton.title = Localizable.manageSubscription
        useCouponButton.title = Localizable.useCoupon

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
        usernameValue.attributedStringValue = viewModel.username.styled(.weak, font: .themeFont(.heading4), alignment: .right)

        if let planTitle = viewModel.planTitle {
            accountPlanValue.attributedStringValue = planTitle.styled(viewModel.maxTier.styleForUI, font: .themeFont(.heading4), alignment: .right)
        } else {
            accountPlanValue.attributedStringValue = Localizable.unavailable.styled(.weak, font: .themeFont(.heading4), alignment: .right)
        }

        useCouponButton.isHidden = !viewModel.canUsePromo
    }
    
    @objc private func manageSubscriptionButtonAction() {
        viewModel.manageSubscriptionAction()
    }

    @objc private func useCoupon() {
        couponViewController.view.frame.origin = CGPoint(x: (view.frame.size.width - AppConstants.Windows.sidebarWidth) / 2, y: 48)
        couponViewController.view.isHidden = false
        DispatchQueue.main.async { [weak self] in
            self?.couponViewController.focus()
        }
    }
}

// MARK: CouponViewControllerDelegate
extension AccountViewController: CouponViewControllerDelegate {
    func couponDidApply(message: String) {
        userDidCloseCouponViewController()
        viewModel.reload()

        banner?.dismiss()
        banner = BannerView(message: message)
        // one level up is the bottom part of the settings container and another level up is the actual container
        banner?.show(from: view.superview?.superview ?? view)
    }

    func userDidCloseCouponViewController() {
        couponViewController.view.isHidden = true
    }
}
