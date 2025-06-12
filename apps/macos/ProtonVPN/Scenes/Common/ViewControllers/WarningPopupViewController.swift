//
//  WarningPopupViewController.swift
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
import Ergonomics
import LegacyCommon
import Strings

class WarningPopupViewController: NSViewController {
    @IBOutlet var bodyView: NSView!
    @IBOutlet var warningImage: NSImageView!
    @IBOutlet var warningDescriptionLabel: NSTextField!
    @IBOutlet var warningScrollViewContainer: NSScrollView!
    @IBOutlet var warningDescription: PVPNTextViewLink!

    @IBOutlet var footerView: NSView!
    @IBOutlet var cancelButton: CancellationButton!
    @IBOutlet var continueButton: PrimaryActionButton!

    var viewModel: WarningPopupViewModel!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    required init(viewModel: WarningPopupViewModel) {
        super.init(nibName: NSNib.Name("WarningPopup"), bundle: nil)
        self.viewModel = viewModel
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBodySection()
        setupFooterSection()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        view.window?.applyWarningAppearance(withTitle: viewModel.title)
    }

    private func setupBodySection() {
        warningScrollViewContainer.isHidden = true
        bodyView.wantsLayer = true
        DarkAppearance {
            bodyView.layer?.backgroundColor = .cgColor(.background, .weak)
        }

        warningImage.image = viewModel.image
        warningDescriptionLabel.attributedStringValue = viewModel.description.styled(alignment: .natural)
    }

    private func setupFooterSection() {
        footerView.wantsLayer = true
        DarkAppearance {
            footerView.layer?.backgroundColor = .cgColor(.background, .weak)
        }

        cancelButton.title = Localizable.cancel
        cancelButton.fontSize = .paragraph
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonAction)

        continueButton.title = Localizable.continue
        continueButton.fontSize = .paragraph
        continueButton.target = self
        continueButton.action = #selector(continueButtonAction)
    }

    @objc
    private func cancelButtonAction() {
        viewModel.onCancel?()
        dismiss(nil)
    }

    @objc
    private func continueButtonAction() {
        viewModel.onConfirm()
        dismiss(nil)
    }
}
