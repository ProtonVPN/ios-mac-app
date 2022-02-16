//
//  UpgradeAdvertViewController.swift
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
import Modals

public final class UpsellViewController: NSViewController {

    @IBOutlet private weak var imageView: NSImageView!
    @IBOutlet private weak var titleLabel: NSTextField! {
        didSet {
            titleLabel.textColor = colors.text
        }
    }
    @IBOutlet private weak var footerLabel: NSTextField! {
        didSet {
            if case .allCountries = upsellType {
                footerLabel.textColor = colors.weakText
                footerLabel.font = .systemFont(ofSize: 12)
            } else {
                footerLabel.removeFromSuperview()
            }
        }
    }
    @IBOutlet private weak var descriptionLabel: NSTextField! {
        didSet {
            descriptionLabel.textColor = colors.text
        }
    }
    @IBOutlet private weak var upgradeButton: UpsellPrimaryActionButton!
    @IBOutlet private weak var featuresStackView: NSStackView!

    var upsellType: UpsellType?

    var upgradeAction: (() -> Void)?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init() {
        super.init(nibName: NSNib.Name("UpsellView"), bundle: .module)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        view.wantsLayer = true
        view.layer?.backgroundColor = colors.background.cgColor
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = Asset.plusCountries.image

        upgradeButton.title = LocalizedString.modalsGetPlus
        setupFeatures()
    }

    func setupFeatures() {
        guard let upsellType = upsellType else { return }
        let upsellFeature = upsellType.upsellFeature()
        titleLabel.stringValue = upsellFeature.title
        descriptionLabel.stringValue = upsellFeature.subtitle
        footerLabel?.stringValue = upsellFeature.footer ?? ""
        imageView.image = upsellFeature.artImage

        for view in featuresStackView.arrangedSubviews {
            view.removeFromSuperview()
        }

        guard !upsellFeature.features.isEmpty else {
            featuresStackView.removeFromSuperview()
            return
        }

        for feature in upsellFeature.features {
            let view = FeatureView()
            view.feature = feature
            featuresStackView.addArrangedSubview(view)
        }
    }

    override public func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyUpsellModalAppearance()
    }

    @IBAction private func upgrade(_ sender: Any) {
        upgradeAction?()
        dismiss(nil)
    }
}
