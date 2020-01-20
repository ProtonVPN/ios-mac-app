//
//  SignUpOptionsViewController.swift
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

class HumanVerificationOptionsViewController: UIViewController {

    private let primaryButtonHeight: CGFloat = 50
    
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var topMessageLabel: UILabel!
    @IBOutlet private weak var instructionLabel: UILabel!
    @IBOutlet private weak var captchaButton: ProtonButton!
    @IBOutlet private weak var emailButton: ProtonButton!
    @IBOutlet private weak var smsButton: ProtonButton!
    @IBOutlet private weak var supportButton: ProtonButton!
    @IBOutlet private weak var underLogoLabel: UILabel!
    
    var viewModel: HumanVerificationOptionsViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        underLogoLabel.text = LocalizedString.loadingScreenSlogan
        self.navigationItem.title = " " // Remove "Back" from back button on navigation bar
        
        setupView()
        setUpInstructions()
        setUpActionButtons()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let errorMessage = viewModel?.getOpeningError() {
            showMessage(errorMessage, type: GSMessageType.error, options: UIConstants.messageOptions)
        }
    }
    
    // MARK: - Private functions
        
    private func setUpInstructions() {
        instructionLabel.attributedText = LocalizedString.selectVerificationOption.attributed(withColor: .protonWhite(), font: .systemFont(ofSize: 17), alignment: .center)
        topMessageLabel.attributedText = LocalizedString.selectVerificationOptionTopMessage.attributed(withColor: .protonWhite(), font: .systemFont(ofSize: 17), alignment: .center)
    }
    
    private func setUpActionButtons() {
        guard let viewModel = viewModel else {
            return
        }
        
        captchaButton.setTitle(LocalizedString.useCaptchaVerification, for: .normal)
        captchaButton.isHidden = !viewModel.showCaptchaOption()
        
        emailButton.setTitle(LocalizedString.useOtherEmailAddress, for: .normal)
        emailButton.isHidden = !viewModel.showEmailOption()
        
        smsButton.setTitle(LocalizedString.useSMSVerification, for: .normal)
        smsButton.isHidden = !viewModel.showSMSOption()
        
        supportButton.setTitle(LocalizedString.requestInvitation, for: .normal)
        supportButton.isHidden = !viewModel.showInviteOption()
    }
    
    private func setupView() {
        view.backgroundColor = .protonPlansGrey()
        
        if self.navigationController != nil {
            closeButton.isHidden = true
            let closeImage = UIImage(named: "close-nav-bar")
            let close2Button = UIBarButtonItem(image: closeImage, style: .done, target: self, action: #selector(closeButtonTapped(_:)))
            self.navigationItem.setLeftBarButton(close2Button, animated: false)
        } else {
            closeButton.tintColor = .protonWhite()
            closeButton.isHidden = false
        }
    }
    
    // MARK: User actions
    
    @IBAction func closeButtonTapped(_ sender: Any) {
        viewModel.cancel()
    }
    
    @IBAction private func backTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction private func emailAction(_ sender: Any) {
        viewModel?.showEmailScreen()
    }
    
    @IBAction private func smsAction(_ sender: Any) {
        viewModel?.showSmsScreen()
    }
    
    @IBAction func contactSupport(_ sender: Any) {
        viewModel?.contactSupport()
    }
    
    @IBAction func captchaAction(_ sender: Any) {
        viewModel?.showCaptchaScreen()
    }
}
