//
//  FeatureTableViewCell.swift
//  ProtonVPN - Created on 21.04.21.
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

import Dependencies

import ProtonCoreUIFoundations

import LegacyCommon
import VPNAppCore

import Strings

class FeatureTableViewCell: UITableViewCell {
    @IBOutlet private var iconIV: UIImageView!
    @IBOutlet private var titleLbl: UILabel!
    @IBOutlet private var descriptionLbl: UILabel!
    @IBOutlet private var learnMoreBtn: UIButton!

    @IBOutlet var loadViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var loadView: UIView!
    @IBOutlet private var loadLowView: UIView!
    @IBOutlet private var loadLowLbl: UILabel!
    @IBOutlet private var loadMediumView: UIView!
    @IBOutlet private var loadMediumLbl: UILabel!
    @IBOutlet private var loadHighView: UIView!
    @IBOutlet private var loadHighLbl: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .backgroundColor()
        learnMoreBtn.setTitleColor(UIColor.textAccent(), for: .normal)
        learnMoreBtn.tintColor = UIColor.textAccent()
        learnMoreBtn.setImage(IconProvider.arrowOutSquare, for: .normal)
    }

    var viewModel: FeatureCellViewModel! {
        didSet {
            titleLbl.text = viewModel.title
            switch viewModel.icon {
            case let .image(image):
                iconIV.image = image
            case let .url(url):
                if let url {
                    iconIV.af.setImage(withURL: url)
                }
            }

            descriptionLbl.text = viewModel.description
            learnMoreBtn.setTitle(Localizable.learnMore, for: .normal)

            if viewModel.displayLoads {
                loadView.isHidden = false
                loadViewHeightConstraint.constant = 32
                loadLowLbl.text = Localizable.performanceLoadLow
                loadLowView.backgroundColor = .notificationOKColor()
                loadMediumLbl.text = Localizable.performanceLoadMedium
                loadMediumView.backgroundColor = .notificationWarningColor()
                loadHighLbl.text = Localizable.performanceLoadHigh
                loadHighView.backgroundColor = .notificationErrorColor()
            } else {
                loadView.isHidden = true
                loadViewHeightConstraint.constant = 0
            }
        }
    }

    // MARK: - Actions

    @IBAction private func didTapLearnMore(_ sender: Any) {
        guard let urlContact = viewModel.urlContact else { return }
        @Dependency(\.linkOpener) var linkOpener
        linkOpener.open(urlContact)
    }
}
