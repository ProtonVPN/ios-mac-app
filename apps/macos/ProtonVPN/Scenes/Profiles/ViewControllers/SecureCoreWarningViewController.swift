//
//  SecureCoreWarningViewController.swift
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
import Strings

final class SecureCoreWarningViewController: NSViewController {
    
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var upgradeButton: PrimaryActionButton!
    @IBOutlet weak var learnMoreButton: InteractiveActionButton!

    private let viewModel: SecureCoreWarningViewModel
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(viewModel: SecureCoreWarningViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("SecureCoreWarning"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupComponents()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        view.window?.applyModalAppearance(withTitle: Localizable.upgradeRequired)
    }
    
    private func setupView() {
        view.wantsLayer = true
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background, .weak)
        }
    }
    
    private func setupComponents() {
        descriptionLabel.usesSingleLineMode = false
        descriptionLabel.cell?.lineBreakMode = .byWordWrapping
        descriptionLabel.attributedStringValue = Localizable.planDoesNotIncludeSecureCore.styled(font: .themeFont(.heading4, bold: true))
        
        upgradeButton.title = Localizable.upgradeRequired
        upgradeButton.target = self
        upgradeButton.action = #selector(upgradeButtonAction)
        
        learnMoreButton.title = Localizable.learnMoreAboutSecureCore
        learnMoreButton.target = self
        learnMoreButton.action = #selector(learnMoreButtonAction)
    }
    
    @objc private func upgradeButtonAction() {
        Task {
            await viewModel.upgradeButtonPressed()
        }
        dismiss(nil)
    }
    
    @objc private func learnMoreButtonAction() {
        viewModel.learnMoreButtonPressed()
        dismiss(nil)
    }
}
