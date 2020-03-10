//
//  SubscriptioInfoController.swift
//  ProtonVPN - Created on 2020-03-09.
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

import UIKit
import vpncore

class SubscriptionInfoController: UIViewController {
    
    // MARK: Properties
    @IBOutlet var navCloseButton: UIBarButtonItem!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var scrollViewBody: UIView!
    
    private let viewModel: SubscriptionInfoViewModel
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(viewModel: SubscriptionInfoViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "SubscriptionInfoController", bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = " " // Remove "Back" from back button on navigation bar
        setupView()
        renderPlanInfo()
    }
    
    private func setupView() {
        view.backgroundColor = .protonPlansGrey()
        
        titleLabel.attributedText = LocalizedString.settingsManageSubscription.attributed(withColor: .protonWhite(), fontSize: 24)
        
        let closeImage = UIImage(named: "close-nav-bar")
        navCloseButton = UIBarButtonItem(image: closeImage, style: .done, target: self, action: #selector(closeButtonTapped(_:)))
        navCloseButton.accessibilityIdentifier = "close"
        self.navigationItem.setLeftBarButton(navCloseButton, animated: false)
            
    }
    
    // MARK: User actions
    
    @IBAction func closeButtonTapped(_ sender: Any) {
        viewModel.cancel()
    }

    // MARK: Views
    
    private func renderPlanInfo() {
        let planView = PlanInfoView.loadViewFromNib() as PlanInfoView
        planView.plan = viewModel.plan
        
        scrollViewBody.add(subView: planView, withTopMargin: 0, rightMargin: 0, bottomMargin: nil, leftMargin: 0)
        
    }
    
}
