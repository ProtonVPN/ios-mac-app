//
//  AnnouncementDetailViewController.swift
//  iOS
//
//  Created by Igor Kulman on 05.10.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import UIKit
import vpncore
import AlamofireImage

final class AnnouncementDetailViewController: UIViewController {

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

    var cancelled: (() -> Void)?
    var urlRequested: ((String) -> Void)?

    private let data: OfferPanel

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(_ data: OfferPanel) {
        self.data = data
        super.init(nibName: "AnnouncementDetailViewController", bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .protonGrey()
        footerView.backgroundColor = .protonGrey()
        closeButton.setImage(closeButton.imageView?.image?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeButton.tintColor = .protonWhite()

        featuresFooterLabel.textColor = .protonUnavailableGrey()
        featuresFooterLabel.text = data.featuresFooter

        pageFooterLabel.textColor = .protonUnavailableGrey()
        pageFooterLabel.text = data.pageFooter
        actionButton.setTitle(data.button.text, for: .normal)

        incentiveLabel.textColor = .protonWhite()
        let parts = data.incentive.split(separator: "%")
        if parts.count != 3 {
            incentiveLabel.text = data.incentive.replacingOccurrences(of: "%IncentivePrice%", with: "\n\(data.incentivePrice)")
        } else {
            let attributed = NSMutableAttributedString(string: String(parts[0]), attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .semibold)])
            attributed.append(NSAttributedString(string: "\n"))
            attributed.append(NSAttributedString(string: data.incentivePrice, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 28, weight: .bold)]))
            attributed.append(NSAttributedString(string: String(parts[2]), attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .semibold)]))
            incentiveLabel.attributedText = attributed
        }

        pillLabel.textColor = .protonWhite()
        pillLabel.text = data.pill

        pillView.backgroundColor = .protonRed()

        titleLabel.textColor = .protonWhite()
        titleLabel.text = data.title

        if let pictureUrl = URL(string: data.pictureURL) {
            pictureView.af.cancelImageRequest()
            pictureView.af.setImage(withURLRequest: URLRequest(url: pictureUrl))
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
