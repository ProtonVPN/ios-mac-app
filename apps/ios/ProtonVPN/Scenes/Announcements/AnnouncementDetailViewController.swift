//
//  AnnouncementDetailViewController.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
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

import Foundation
import UIKit
import LegacyCommon
import Alamofire
import ProtonCoreUIFoundations

final class AnnouncementDetailViewController: AnnouncementViewController {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var actionButton: UIButton!
    @IBOutlet private weak var pageFooterLabel: UILabel!
    @IBOutlet private weak var incentiveLabel: UILabel!
    @IBOutlet private weak var footerView: UIView!
    @IBOutlet private weak var pillView: UIView!
    @IBOutlet private weak var pillLabel: UILabel!
    @IBOutlet private weak var pictureView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var featuresStackView: UIStackView!
    @IBOutlet private weak var featuresFooterLabel: UILabel!

    private let data: OfferPanel.LegacyPanel

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(_ data: OfferPanel.LegacyPanel) {
        self.data = data
        super.init(nibName: String(describing: AnnouncementDetailViewController.self), bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .backgroundColor()
        footerView.backgroundColor = .backgroundColor()
        closeButton.setImage(IconProvider.crossBig, for: .normal)
        closeButton.tintColor = .normalTextColor()

        featuresFooterLabel.textColor = .weakTextColor()
        featuresFooterLabel.text = data.featuresFooter

        pageFooterLabel.textColor = .weakTextColor()
        pageFooterLabel.text = data.pageFooter
        actionButton.setTitle(data.button.text, for: .normal)

        incentiveLabel.textColor = .normalTextColor()
        let parts = data.incentive.components(separatedBy: "%IncentivePrice%")
        if parts.count == 1 {
            incentiveLabel.text = data.incentive
        } else {
            let attributed = NSMutableAttributedString(string: String(parts[0]), attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .semibold)])
            attributed.append(NSAttributedString(string: "\n"))
            attributed.append(NSAttributedString(string: data.incentivePrice, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 28, weight: .bold)]))
            attributed.append(NSAttributedString(string: parts.dropFirst().joined(separator: ""), attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .semibold)]))
            incentiveLabel.attributedText = attributed
        }

        pillLabel.textColor = .normalTextColor()
        pillLabel.text = data.pill

        pillView.backgroundColor = .notificationErrorColor()

        titleLabel.textColor = .normalTextColor()
        titleLabel.text = data.title

        if let pictureUrl = URL(string: data.pictureURL) {
            pictureView.af.setImage(withURLRequest: URLRequest(url: pictureUrl), imageTransition: .crossDissolve(0.2))
        }

        for view in featuresStackView.arrangedSubviews {
            view.removeFromSuperview()
            featuresStackView.removeArrangedSubview(view)
        }

        for feature in data.features {
            let featureView = AnnouncementFeatureView()
            featureView.model = feature
            featuresStackView.addArrangedSubview(featureView)
        }
    }

    @IBAction private func actionButtonTapped(_ sender: Any) {
        urlRequested?(data.button.url)
    }

    @IBAction private func closeButtonTapped(_ sender: Any) {
        cancelled?()
    }
}
