//
//  OnboardingViewController.swift
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

import UIKit
import vpncore

class OnboardingViewController: UIViewController {
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var nextButton: ProtonButton!
    @IBOutlet weak var authenticationStackView: UIStackView!
    @IBOutlet weak var signUpButton: ProtonButton!
    @IBOutlet weak var logInButton: ProtonButton!
    @IBOutlet weak var secondaryButton: UIButton!
    
    private lazy var endpointLabel: UILabel = UILabel()
    private lazy var endpointPickerToolbar: UIToolbar = UIToolbar()
    private lazy var endpointPicker: UIPickerView = UIPickerView()
    
    private let viewModel: OnboardingViewModel
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: "Onboarding", bundle: nil)
        
        self.viewModel.configureUiForIndex = { [weak self] in self?.configureButtons() }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup container view controller as sub view
        addChild(viewModel.pageViewController)
        viewModel.pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(viewModel.pageViewController.view)
        
        NSLayoutConstraint.activate([
            viewModel.pageViewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            viewModel.pageViewController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            viewModel.pageViewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            viewModel.pageViewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        viewModel.pageViewController.didMove(toParent: self)
        
        view.backgroundColor = .protonBlack()
        
        secondaryButton.setTitleColor(.protonWhite(), for: .normal)
        secondaryButton.titleLabel?.font = .systemFont(ofSize: 16)
        setupButtons()
        configureButtons()
        
        #if !RELEASE
        configureApiEnpointLabel()
        #endif
    }
    
    private func setupButtons() {
        UIView.performWithoutAnimation { [unowned self] in
            self.nextButton.setTitle(LocalizedString.next, for: .normal)
            self.signUpButton.setTitle(LocalizedString.signUp, for: .normal)
            self.logInButton.setTitle(LocalizedString.logIn, for: .normal)
        }
    }
    
    private func configureButtons() {
        UIView.performWithoutAnimation { [unowned self] in
            self.nextButton.isHidden = viewModel.hideNextButton()
            self.authenticationStackView.isHidden = viewModel.hideAuthenticationButtons()
            
            self.secondaryButton.setTitle(viewModel.secondaryButtonTitle(), for: .normal)
            self.secondaryButton.accessibilityIdentifier = viewModel.secondaryButtonAccessibilityId()
            self.secondaryButton.layoutIfNeeded()
        }
    }
    
    private func configureApiEnpointLabel() {
        endpointLabel.translatesAutoresizingMaskIntoConstraints = false
        endpointLabel.addConstraint(NSLayoutConstraint(item: endpointLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 44))
        
        view.addSubview(endpointLabel)
        view.addConstraint(NSLayoutConstraint(item: endpointLabel, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leadingMargin, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: endpointLabel, attribute: .top, relatedBy: .equal, toItem: view, attribute: .topMargin, multiplier: 1, constant: 40))
        view.addConstraint(NSLayoutConstraint(item: endpointLabel, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailingMargin, multiplier: 1, constant: 0))
        
        endpointLabel.text = viewModel.endpoint
        endpointLabel.textColor = .systemBlue
        endpointLabel.textAlignment = .center
        
        endpointLabel.isUserInteractionEnabled = true
        endpointLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(endpointLabelTapped)))
    }
    
    @IBAction private func nextAction(_ sender: Any) {
        viewModel.next()
    }
    
    @IBAction private func secondaryAction(_ sender: Any) {
        viewModel.performSecondaryAction()
    }
    
    @IBAction private func signUpAction(_ sender: Any) {
        viewModel.signUp()
    }
    
    @IBAction private func logInAction(_ sender: Any) {
        viewModel.logIn()
    }
    
    @objc private func endpointLabelTapped() {
        guard endpointPicker.superview == nil else {
            return // picker already displaying
        }
        
        endpointPicker.translatesAutoresizingMaskIntoConstraints = false
        
        endpointPicker.addConstraint(NSLayoutConstraint(item: endpointPicker, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 300))
        
        view.addSubview(endpointPicker)
        view.addConstraint(NSLayoutConstraint(item: endpointPicker, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: endpointPicker, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: endpointPicker, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: 0))
        
        endpointPicker.delegate = viewModel
        endpointPicker.dataSource = viewModel
        
        endpointPicker.backgroundColor = .protonBlack()
        endpointPicker.showsSelectionIndicator = true
        
        guard endpointPickerToolbar.superview == nil else {
            return // toolbar already displaying
        }
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissPicker))
        endpointPickerToolbar.setItems([flexibleSpace, doneButton], animated: false)
        endpointPickerToolbar.isUserInteractionEnabled = true
        
        endpointPickerToolbar.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(endpointPickerToolbar)
        view.addConstraint(NSLayoutConstraint(item: endpointPickerToolbar, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: endpointPickerToolbar, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: endpointPickerToolbar, attribute: .bottom, relatedBy: .equal, toItem: endpointPicker, attribute: .top, multiplier: 1, constant: 0))
    }
    
    @objc private func dismissPicker() {
        endpointLabel.text = viewModel.endpoint
        
        endpointPickerToolbar.removeFromSuperview()
        endpointPicker.removeFromSuperview()
    }
}
