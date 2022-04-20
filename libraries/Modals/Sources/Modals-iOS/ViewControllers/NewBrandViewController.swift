//
//  Created on 28/03/2022.
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

import Modals
import UIKit

final class NewBrandViewController: UIViewController, UITextViewDelegate {

    @IBOutlet private weak var iconBackground: UIImageView!
    @IBOutlet private weak var newBrandBackground: UIImageView!
    @IBOutlet private weak var newBrandBackgroundHeight: NSLayoutConstraint!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleTextView: UITextView!
    @IBOutlet private weak var gotItButton: UIButton!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private var servicesIcons: [UIImageView]!
    @IBOutlet weak var subtitleTextViewHeightConstraint: NSLayoutConstraint!

    var onDismiss: (() -> Void)?
    var onReadMore: (() -> Void)?
    var icons: NewBrandIcons?

    let feature = NewBrandFeature()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .init(red: 0, green: 0, blue: 0, alpha: 0.52)
        setupOutlets()
        setupFeature()
        setupIcons()
    }

    private func setupIcons() {
        guard let icons = icons else {
            return
        }
        for (index, icon) in [icons.mailMain, icons.calendarMain, icons.driveMain, icons.vpnMain].enumerated() {
            servicesIcons[index].image = icon
        }
    }

    private func setupOutlets() {
        newBrandBackground.layer.cornerRadius = 8

        contentView.layer.cornerRadius = 8
        contentView.backgroundColor = colors.background

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = colors.text

        subtitleTextView.isScrollEnabled = false
        subtitleTextView.delegate = self
        subtitleTextView.showsHorizontalScrollIndicator = false
        subtitleTextView.showsVerticalScrollIndicator = false
        let width = subtitleTextView.contentSize.width
        let size = subtitleTextView.sizeThatFits(.init(width: width, height: .infinity))
        subtitleTextViewHeightConstraint.constant = size.height

        actionButtonStyle(gotItButton)
    }

    func textViewDidChange(_ textView: UITextView) {
        textView.textAlignment = .center
    }

    private func setupFeature() {
        newBrandBackground.image = feature.artImage
        iconBackground.image = feature.iconImage

        titleLabel.text = feature.title
        subtitleTextView.attributedText = subtitleLabelText()
        subtitleTextView.textAlignment = .center
        subtitleTextView.linkTextAttributes = [.font: UIFont.systemFont(ofSize: 14, weight: .regular),
                                               .foregroundColor: colors.textAccent]

        gotItButton.setTitle(feature.gotIt, for: .normal)
    }

    private func subtitleLabelText() -> NSAttributedString {
        let text = NSMutableAttributedString(string: feature.subtitle,
                                             attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .regular),
                                                          .foregroundColor: colors.weakText])
        text.append(NSAttributedString(string: " " + feature.learnMore,
                                       attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .regular)]))
        text.setAsLink(textToFind: feature.learnMore, linkURL: feature.readMoreLink)
        return text
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = feature.artImage.size
        newBrandBackgroundHeight.constant = contentView.bounds.size.width * (size.height / size.width)
    }

    @IBAction private func readMoreButtonTapped(_ sender: UIButton) {
        presentingViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.onReadMore?()
        })
    }

    @IBAction private func dismissButtonTapped(_ sender: UIButton) {
        presentingViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.onDismiss?()
        })
    }
}
