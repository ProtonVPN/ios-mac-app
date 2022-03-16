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

import Cocoa
import SDWebImage
import vpncore

final class AnnouncementDetailViewController: NSViewController {
    @IBOutlet private weak var incentiveLabel: NSTextField!
    @IBOutlet private weak var pillView: NSView!
    @IBOutlet private weak var pillLabel: NSTextField!
    @IBOutlet private weak var pictureView: NSImageView!
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var featuresStackView: NSStackView!
    @IBOutlet private weak var featuresFooterLabel: NSTextField!
    @IBOutlet private weak var actionButton: PrimaryActionButton!
    @IBOutlet private weak var pageFooterLabel: NSTextField!

    private let data: OfferPanel

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(_ data: OfferPanel) {
        self.data = data
        super.init(nibName: NSNib.Name(String(describing: AnnouncementDetailViewController.self)), bundle: nil)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance(withTitle: data.title)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        incentiveLabel.textColor = .color(.text)
        let parts = data.incentive.components(separatedBy: "%IncentivePrice%")
        if parts.count == 1 {
            incentiveLabel.stringValue = data.incentive
        } else {
            let attributed = NSMutableAttributedString(string: String(parts[0]), attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: .semibold)])
            attributed.append(NSAttributedString(string: "\n"))
            attributed.append(NSAttributedString(string: data.incentivePrice, attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 28, weight: .bold)]))
            attributed.append(NSAttributedString(string: parts.dropFirst().joined(separator: ""), attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            attributed.addAttributes([NSAttributedString.Key.paragraphStyle: paragraph], range: NSRange(location: 0, length: attributed.length))
            incentiveLabel.attributedStringValue = attributed
        }

        pillLabel.textColor = .color(.text)
        pillLabel.stringValue = data.pill

        pillView.wantsLayer = true
        pillView.layer?.backgroundColor = .cgColor(.background, .danger)

        if let pictureUrl = URL(string: data.pictureURL) {
            pictureView.sd_setImage(with: pictureUrl, completed: nil)
        }

        for feature in data.features {
            let featureView = AnnouncementFeatureView(model: feature)
            featureView.translatesAutoresizingMaskIntoConstraints = false
            featuresStackView.addArrangedSubview(featureView)
        }

        titleLabel.textColor = .color(.text)
        titleLabel.stringValue = data.title

        featuresFooterLabel.textColor = .color(.text, .weak)
        featuresFooterLabel.stringValue = data.featuresFooter

        actionButton.title = data.button.text
        actionButton.contentTintColor = .color(.icon)

        pageFooterLabel.textColor = .color(.text, .weak)
        pageFooterLabel.stringValue = data.pageFooter
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        pillView.layer?.cornerRadius = pillView.frame.height / 2
    }

    @IBAction private func didTapActionButton(_ sender: Any) {
        SafariService.openLink(url: data.button.url)
    }
}
