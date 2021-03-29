//
//  PlanSelectionViewController.swift
//  ProtonVPN - Created on 01.07.19.
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

import GSMessages
import UIKit
import vpncore

class PlanSelectionViewController: UIViewController {
    
    // MARK: Properties
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet var navCloseButton: UIBarButtonItem!
    @IBOutlet weak var upgradeLabel: UILabel!
    @IBOutlet weak var plansStack: UIStackView!
    @IBOutlet weak var footerLabel: UILabel!
    @IBOutlet weak var selectButton: ProtonButton!
    @IBOutlet weak var shadowView: UIView!
    @IBOutlet weak var advancedFeaturesHolderView: UIView!
    private let animationDuration: TimeInterval = 0.25
    
    private let cardPeek: CGFloat = 30
    
    private let viewModel: PlanSelectionViewModel
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(_ viewModel: PlanSelectionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "PlanSelection", bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        addViewsToScrollView()
        selectedPlanChanged()
        
        self.navigationItem.title = " " // Remove "Back" from back button on navigation bar
        viewModel.navigationController = self.navigationController
        viewModel.selectedPlanChanged = { [weak self] in
            self?.selectedPlanChanged()
        }
        viewModel.selectionLoadingChanged = { [weak self] isLoading in
            if isLoading {
                self?.selectButton.showLoading()
                self?.selectButton.isEnabled = false
            } else {
                self?.selectButton.hideLoading()
                self?.selectButton.isEnabled = self?.viewModel.selectedPlan != nil
            }
        }
        viewModel.plansChanged = { [weak self] in
            self?.addViewsToScrollView()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewBecameVisible = true
    }
    
    private func setupView() {
        view.backgroundColor = .protonPlansGrey()
        selectButton.accessibilityIdentifier = "Select plan"
        if !viewModel.allowDismissal {
            closeButton.isHidden = true
        } else {
            if self.navigationController != nil {
                closeButton.isHidden = true
                let closeImage = UIImage(named: "close-nav-bar")
                navCloseButton = UIBarButtonItem(image: closeImage, style: .done, target: self, action: #selector(closeButtonTapped(_:)))
                navCloseButton.accessibilityIdentifier = "close"
                self.navigationItem.setLeftBarButton(navCloseButton, animated: false)
            } else {
                closeButton.tintColor = .protonWhite()
                closeButton.isHidden = !viewModel.allowDismissal
            }
        }
        
        upgradeLabel.attributedText = viewModel.headingString.attributed(withColor: .protonWhite(), fontSize: 24)
        
        footerLabel.text = LocalizedString.plansFooter
        footerLabel.textColor = .protonFontDark()
        
        selectButton.setTitle(LocalizedString.selectPlan, for: .normal)
        
        shadowView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(shadowTapped(_:))))
    }
    
    private func addViewsToScrollView() {
        plansStack.arrangedSubviews.forEach({view in
            plansStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        })
        
        guard !viewModel.plans.isEmpty else {
            let indicator = UIActivityIndicatorView()
            plansStack.addArrangedSubview(indicator)
            indicator.startAnimating()
            return
        }
        
        viewModel.plans.enumerated().forEach { (i: Int, plan: AccountPlan) in
            let planView = PlanCardView.loadViewFromNib() as PlanCardView
            planView.presenter = PlanCardViewPresenterImplementation(plan, storeKitManager: viewModel.storeKitManager) { [weak self] plan in
                self?.showAdvancedFeatures(forPlan: plan)
            }

            plansStack.addArrangedSubview(planView)
            planView.accessibilityIdentifier = plan.rawValue
            planView.leadingAnchor.constraint(equalTo: plansStack.leadingAnchor).isActive = true
            planView.trailingAnchor.constraint(equalTo: plansStack.trailingAnchor).isActive = true
            planView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(planViewSelected(_:))))
        }
    }
    
    @objc private func planViewSelected(_ recognizer: UIGestureRecognizer) {
        guard let planView = recognizer.view as? PlanCardView, let plan = planView.presenter.plan else {
            return
        }
        viewModel.selectedPlan = plan
    }
    
    private func selectedPlanChanged() {
        plansStack.subviews.forEach { view in
            guard let planView = view as? PlanCardView else { return }
            planView.setSelected(planView.presenter.plan == viewModel.selectedPlan)
        }        
        if let plan = viewModel.selectedPlan {
            if plan.storeKitProductId != nil { // keeps button enabled if free or trial
                let enabled = viewModel.storeKitManager.readyToPurchaseProduct()
                selectButton.isEnabled = enabled
            } else {
                selectButton.isEnabled = true
            }
        } else {
            selectButton.isEnabled = false
        }
    }
    
    // MARK: User actions
    
    @IBAction func closeButtonTapped(_ sender: Any) {
        viewModel.cancel()
    }
    
    @IBAction func selectButtonTapped(_ sender: Any) {
        guard let plan = viewModel.selectedPlan else { return }
        viewModel.finishPlanSelection(plan)
    }
 
    @IBAction func shadowTapped(_ sender: Any) {
        hideAdvancedFeatures()
    }
    
    // MARK: Advanced features
    
    private func showAdvancedFeatures(forPlan plan: AccountPlan) {
        let planView = PlanAdvancedFeaturesView.loadViewFromNib() as PlanAdvancedFeaturesView
        advancedFeaturesHolderView.addFillingSubview(planView)
        planView.plan = plan
        planView.closeButton.addTarget(self, action: #selector(shadowTapped), for: .touchUpInside)
        view.setNeedsLayout()
        
        advancedFeaturesHolderView.alpha = 0
        shadowView.alpha = 0
        advancedFeaturesHolderView.isHidden = false
        shadowView.isHidden = false
        
        UIView.animate(withDuration: animationDuration) {
            self.advancedFeaturesHolderView.alpha = 1
            self.shadowView.alpha = 0.67
        }
        self.navigationItem.setLeftBarButton(nil, animated: animationDuration > 0)
    }
    
    private func hideAdvancedFeatures() {
        UIView.animate(withDuration: animationDuration, animations: {
            self.advancedFeaturesHolderView.alpha = 0
            self.shadowView.alpha = 0
        }, completion: { _ in
            self.advancedFeaturesHolderView.isHidden = true
            self.shadowView.isHidden = true
            self.advancedFeaturesHolderView.subviews.forEach { subview in
                subview.removeFromSuperview()
            }
        })
        self.navigationItem.setLeftBarButton(navCloseButton, animated: animationDuration > 0)
    }
    
}
