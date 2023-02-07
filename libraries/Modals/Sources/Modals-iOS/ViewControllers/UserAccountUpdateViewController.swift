//
//  UserAccountUpdateViewController.swift
//  ProtonVPN - Created on 05.04.21.
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
import Modals

class UserAccountUpdateViewController: UIViewController {

    @IBOutlet private weak var reconnectionView: UIView!
    @IBOutlet private weak var serversView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var titleLbl: UILabel!
    @IBOutlet private weak var descriptionLbl: UILabel!

    @IBOutlet private weak var featuresTitleLbl: UILabel!

    @IBOutlet private weak var primaryActionBtn: UIButton!
    @IBOutlet private weak var secondActionBtn: UIButton!

    @IBOutlet private weak var feature1View: UIView!
    @IBOutlet private weak var feature1Lbl: UILabel!

    @IBOutlet private weak var feature2View: UIView!
    @IBOutlet private weak var feature2Lbl: UILabel!

    @IBOutlet private weak var feature3View: UIView!
    @IBOutlet private weak var feature3Lbl: UILabel!

    @IBOutlet private weak var fromServerTitleLbl: UILabel!
    @IBOutlet private weak var fromServerIV: UIImageView!
    @IBOutlet private weak var fromServerLbl: UILabel!

    @IBOutlet private weak var toServerTitleLbl: UILabel!
    @IBOutlet private weak var toServerIV: UIImageView!
    @IBOutlet private weak var toServerLbl: UILabel!

    @IBOutlet private var checkmarks: [UIImageView]!

    var viewModel: UserAccountUpdateViewModel!

    var onPrimaryButtonTap: (() -> Void)?

    // MARK: - View Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Remove the title on start, it caused an animation of the title changing to show from the one defined in xib to the target one.
        primaryActionBtn.setTitle(nil, for: .normal)
        secondActionBtn.setTitle(nil, for: .normal)

        serversView.layer.cornerRadius = 8
        serversView.layer.borderWidth = 1
        serversView.layer.borderColor = colors.weakInteraction.cgColor
        titleLbl.text = viewModel.title
        descriptionLbl.text = viewModel.subtitle

        baseViewStyle(view)
        titleStyle(titleLbl)
        subtitleStyle(descriptionLbl)
        actionButtonStyle(primaryActionBtn)
        actionTextButtonStyle(secondActionBtn)
        baseTextStyle(featuresTitleLbl)

        featureTextStyle(feature1Lbl)
        featureTextStyle(feature2Lbl)
        featureTextStyle(feature3Lbl)

         if let image = viewModel.image {
             imageView.image = image
         } else {
             imageView.isHidden = true
         }

        checkmarks.forEach {
            $0.image = viewModel.checkmark
        }

        setupFeatures()
        setupActions()
        setupServers()
    }

    // MARK: - Private

    private func setupFeatures() {
        guard let options = viewModel.options, !options.isEmpty else {
            [feature1View, feature2View, feature3View, featuresTitleLbl].forEach {
                $0?.isHidden = true
            }
            return
        }
        feature1Lbl.text = options[0]
        feature2Lbl.text = options[1]
        feature3Lbl.text = options[2]
    }

    private func setupActions() {
        primaryActionBtn.setTitle(viewModel.primaryButtonTitle, for: .normal)

        if let title = viewModel.secondaryButtonTitle {
            secondActionBtn.setTitle(title, for: .normal)
        } else {
            secondActionBtn.isHidden = true
        }
    }

    private func setupServers() {
        guard let fromServer = viewModel.fromServer,
              let toServer = viewModel.toServer else {
            reconnectionView.isHidden = true
            return
        }

        setServerHeader(fromServer, fromServerIV, fromServerLbl)
        setServerHeader(toServer, toServerIV, toServerLbl)

        fromServerTitleLbl.text = viewModel.fromServerTitle
        toServerTitleLbl.text = viewModel.toServerTitle
    }

    private func setServerHeader( _ server: (String, Image), _ flag: UIImageView, _ serverName: UILabel) {
        serverName.text = server.0
        flag.image = server.1
    }

    // MARK: - Actions

    @IBAction private func didTapPrimaryAction(_ sender: Any) {
        dismiss(animated: true, completion: { [weak self] in
            self?.onPrimaryButtonTap?()
        })
    }

    @IBAction private func didTapSecondAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
