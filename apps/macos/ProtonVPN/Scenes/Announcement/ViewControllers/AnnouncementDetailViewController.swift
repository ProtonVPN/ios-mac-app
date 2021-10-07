//
//  AnnouncementDetailViewController.swift
//  ProtonVPN-mac
//
//  Created by Igor Kulman on 07.10.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
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
        super.init(nibName: NSNib.Name("AnnouncementDetailViewController"), bundle: nil)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance(withTitle: data.title)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        incentiveLabel.textColor = .protonWhite()
        let parts = data.incentive.split(separator: "%")
        if parts.count != 3 {
            incentiveLabel.stringValue = data.incentive.replacingOccurrences(of: "%IncentivePrice%", with: "\n\(data.incentivePrice)")
        } else {
            let attributed = NSMutableAttributedString(string: String(parts[0]), attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: .semibold)])
            attributed.append(NSAttributedString(string: "\n"))
            attributed.append(NSAttributedString(string: data.incentivePrice, attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 28, weight: .bold)]))
            attributed.append(NSAttributedString(string: String(parts[2]), attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            attributed.addAttributes([NSAttributedString.Key.paragraphStyle: paragraph], range: NSRange(location: 0, length: attributed.length))
            incentiveLabel.attributedStringValue = attributed
        }

        pillLabel.textColor = .protonWhite()
        pillLabel.stringValue = data.pill

        pillView.wantsLayer = true
        pillView.layer?.backgroundColor = NSColor.protonRed().cgColor

        if let pictureUrl = URL(string: data.pictureURL) {
            pictureView.sd_setImage(with: pictureUrl, completed: nil)
        }

        for feature in data.features {
            let featureView = AnnouncementFeatureView(model: feature)
            featureView.translatesAutoresizingMaskIntoConstraints = false
            featuresStackView.addArrangedSubview(featureView)
        }

        titleLabel.textColor = .protonWhite()
        titleLabel.stringValue = data.title

        featuresFooterLabel.textColor = .protonUnavailableGrey()
        featuresFooterLabel.stringValue = data.featuresFooter

        actionButton.title = data.button.text
        actionButton.contentTintColor = NSColor.protonWhite()

        pageFooterLabel.textColor = .protonUnavailableGrey()
        pageFooterLabel.stringValue = data.pageFooter
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        pillView.layer?.cornerRadius = pillView.frame.height / 2
    }
}
