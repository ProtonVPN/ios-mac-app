//
//  TrialWelcomeViewController.swift
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

class TrialWelcomeViewController: UIViewController {

    @IBOutlet private weak var headingLabel: UILabel!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var trialEndingLabel: UILabel!
    @IBOutlet private weak var timeRemainingLabel: UILabel!
    @IBOutlet private weak var upgradeButton: ProtonButton!
    @IBOutlet private weak var exitButton: ProtonButton!
    
    private let viewModel: TrialWelcomeViewModel
    private let windowService: WindowService
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(_ viewModel: TrialWelcomeViewModel, windowService: WindowService) {
        self.viewModel = viewModel
        self.windowService = windowService
        
        super.init(nibName: "TrialWelcome", bundle: nil)
        
        modalPresentationStyle = .formSheet
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setUpViews()
    }

    private func setUpViews() {
        view.backgroundColor = .protonBlack()
        
        setUpHeading()
        setUpImage()
        setUpDescription()
        setUpTrialEndingLabel()
        setUpTimeRemainingLabel()
        setUpUpgradeButton()
        setUpExitButton()
    }
    
    private func setUpHeading() {
        headingLabel.attributedText = LocalizedString.trialWelcomeHeadingIos.uppercased().attributed(withColor: .protonWhite(), font: UIFont.boldSystemFont(ofSize: 24), alignment: .center)
    }
    
    private func setUpImage() {
        imageView.image = UIImage(named: "gift")
    }
    
    private func setUpDescription() {
        descriptionLabel.attributedText = LocalizedString.trialWelcomeDescriptionIos.attributed(withColor: .protonWhite(), fontSize: 17, alignment: .center)
    }
    
    private func setUpTrialEndingLabel() {
        trialEndingLabel.attributedText = LocalizedString.trialWelcomeEndsInIos.attributed(withColor: .protonFontLightGrey(), fontSize: 17, alignment: .center)
    }
    
    private func setUpTimeRemainingLabel() {
        timeRemainingLabel.attributedText = viewModel.timeRemainingAttributedString()
    }
    
    private func setUpUpgradeButton() {
        upgradeButton.setTitle(LocalizedString.upgradeNow, for: .normal)
        upgradeButton.isHidden = !viewModel.canUpgrade()
    }
    
    private func setUpExitButton() {
        exitButton.customState = .secondary
        exitButton.setTitle(viewModel.cancelButtonTitle().capitalized, for: .normal)
        exitButton.accessibilityIdentifier = "Maybe Later"
    }
    
    @IBAction private func upgradeAction(_ sender: Any) {
        dismiss(animated: false, completion: { [viewModel] in
            viewModel.selectUpgrade()
        })
    }
    
    @IBAction private func exitAction(_ sender: Any) {
        dismiss(animated: true, completion: { [weak self] in
            self?.windowService.dismissModal()            
        })
    }
}
