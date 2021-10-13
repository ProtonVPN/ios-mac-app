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
    @IBOutlet weak var buyButton: ProtonButton!
    
    private let textFontSize: CGFloat = 14
    
    private let viewModel: SubscriptionInfoViewModel 
    private let alertService: CoreAlertService
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(viewModel: SubscriptionInfoViewModel, alertService: CoreAlertService) {
        self.viewModel = viewModel
        self.alertService = alertService
        super.init(nibName: "SubscriptionInfoController", bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = " " // Remove "Back" from back button on navigation bar
        setupView()
        render()
        
        viewModel.showError = { [weak self] error in
            self?.showError(error)
        }
        viewModel.showSuccess = { [weak self] text in
            self?.showSuccess(message: text)
        }
        viewModel.loadingStateChanged = { [weak self] loading in
            self?.showLoading(loading)
        }
    }
    
    private func setupView() {
        view.backgroundColor = .backgroundColor()
        
        titleLabel.attributedText = LocalizedString.manageSubscription.attributed(withColor: .normalTextColor(), fontSize: 24)
        
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
    
    private func render() {
        scrollViewBody.subviews.forEach { view in
            view.removeFromSuperview()
        }
        
        // Plan
        let planView = PlanInfoView.loadViewFromNib() as PlanInfoView
        planView.plan = viewModel.plan
        scrollViewBody.add(subView: planView, withTopMargin: 0, rightMargin: 0, bottomMargin: nil, leftMargin: 0)
        
        var lastView: UIView = planView
        
        // Expiration
        if let expirationText = viewModel.expirationText {
            lastView = addExpirationLabel(text: expirationText, lastView: lastView)
        }
        
        // Description
        if let description = viewModel.description {
            lastView = addDescritpionLabel(text: description, lastView: lastView)
        }
        
        // Buy button
        buyButton.removeFromSuperview()
        if viewModel.showBuyButton {
            lastView = addBuyButton(lastView: lastView)
        }
        
        // Footer text
        if let footerText = viewModel.footerText {
            lastView = addFooterLabel(text: footerText, lastView: lastView)
        }
        
        scrollViewBody.bottomAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 24).isActive = true
    }
    
    private func addExpirationLabel(text: String, lastView: UIView) -> UIView {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: textFontSize)
        label.text = text
        label.numberOfLines = 0
            
        scrollViewBody.add(subView: label, withTopMargin: nil, rightMargin: 0, bottomMargin: nil, leftMargin: 0)
        label.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 24).isActive = true
        return label
    }
    
    private func addDescritpionLabel(text: String, lastView: UIView) -> UIView {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .justified
        label.font = UIFont.systemFont(ofSize: textFontSize)
        label.text = text
        label.textColor = .weakTextColor()
        label.numberOfLines = 0
        
        scrollViewBody.add(subView: label, withTopMargin: nil, rightMargin: 0, bottomMargin: nil, leftMargin: 0)
        label.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 24).isActive = true
        return label
    }
    
    private func addBuyButton(lastView: UIView) -> UIView {
        let button = buyButton!
        button.translatesAutoresizingMaskIntoConstraints = false
        button.styleCenterMultiline()
        button.setTitle(LocalizedString.subscriptionButton(viewModel.planPrice), for: .normal)
        button.addTarget(self, action: #selector(onButtonClick), for: .touchUpInside)

        scrollViewBody.add(subView: button, withTopMargin: nil, rightMargin: nil, bottomMargin: nil, leftMargin: nil)
        button.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 24).isActive = true
        button.centerXAnchor.constraint(equalTo: scrollViewBody.centerXAnchor).isActive = true
        return button
    }
    
    private func addFooterLabel(text: String, lastView: UIView) -> UIView {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .justified
        label.font = UIFont.systemFont(ofSize: textFontSize)
        label.text = text
        label.textColor = .weakTextColor()
        label.numberOfLines = 0
        
        scrollViewBody.add(subView: label, withTopMargin: nil, rightMargin: 0, bottomMargin: nil, leftMargin: 0)
        label.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 24).isActive = true
        return label
    }
    
    private func showError(_ error: Error) {
        PMLog.ET(error.localizedDescription)
        alertService.push(alert: ErrorNotificationAlert(error: error))
    }
    
    private func showSuccess(message: String) {
        alertService.push(alert: SuccessNotificationAlert(message: message))
    }
    
    private func showLoading(_ loading: Bool) {
        if loading {
            buyButton.showLoading()
            buyButton.isEnabled = false
        } else {
            buyButton.hideLoading()
            buyButton.isEnabled = true
            render()
        }
    }
    
    // MARK: - Actions
    
    @IBAction func onButtonClick() {
        viewModel.startBuy()
    }
    
}
