//
//  Created on 30/03/2022.
//
//  Copyright (c) 2022 Proton AG
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

import AppKit
import Modals

final class NewBrandViewController: NSViewController {

    @IBOutlet private weak var iconBackground: NSImageView!
    @IBOutlet private weak var newBrandBackground: NSImageView!
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var subtitleLabel: NSTextField!
    @IBOutlet private weak var learnMoreButton: NSButton!
    @IBOutlet private weak var readMoreButton: UpsellPrimaryActionButton!
    @IBOutlet private weak var mailIcon: NSImageView!
    @IBOutlet private weak var calendarIcon: NSImageView!
    @IBOutlet private weak var driveIcon: NSImageView!
    @IBOutlet private weak var vpnIcon: NSImageView!

    var onReadMore: (() -> Void)?
    var icons: NewBrandIcons?

    let feature = NewBrandFeature()

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init() {
        super.init(nibName: NSNib.Name("NewBrandView"), bundle: .module)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        view.wantsLayer = true
        view.layer?.backgroundColor = colors.background.cgColor
        newBrandBackground.wantsLayer = true

        learnMoreButton.attributedTitle = NSAttributedString(string: LocalizedString.modalsCommonLearnMore, attributes: [.foregroundColor: colors.linkNorm, .font: NSFont.systemFont(ofSize: 14)])

    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupOutlets()
        setupFeature()
    }

    private func setupOutlets() {
        newBrandBackground.layer?.cornerRadius = 8
        titleLabel.textColor = colors.text
        subtitleLabel.allowsEditingTextAttributes = true
        subtitleLabel.isSelectable = true
    }

    private func setupFeature() {
        mailIcon.image = icons?.mailMain
        calendarIcon.image = icons?.calendarMain
        driveIcon.image = icons?.driveMain
        vpnIcon.image = icons?.vpnMain
        readMoreButton.title = feature.gotIt
        iconBackground.image = feature.iconImage
        newBrandBackground.image = feature.artImage
        titleLabel.stringValue = feature.title
        subtitleLabel.attributedStringValue = subtitleLabelText()
    }

    private func subtitleLabelText() -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let text = NSMutableAttributedString(string: feature.subtitle,
                                             attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .regular),
                                                          .foregroundColor: colors.text,
                                                          .paragraphStyle: style])
        return text
    }

    @IBAction func learnMoreTapped(_ sender: NSButton) {
        onReadMore?()
    }

    override public func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyUpsellModalAppearance()
    }

    @IBAction private func readMoreButtonTapped(_ sender: NSButton) {
        dismiss(nil)
    }
}
