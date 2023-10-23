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
import SwiftUI
import Modals
import Ergonomics
import Strings
import Theme

public final class UpsellViewController: NSViewController {

    @IBOutlet private weak var borderView: NSView! {
        didSet {
            borderView.wantsLayer = true
            borderView.layer?.backgroundColor = .clear
            DarkAppearance {
                borderView.layer?.borderColor = NSColor.color(.border).cgColor
            }
            borderView.layer?.cornerRadius = .themeRadius12
            borderView.layer?.borderWidth = 1
        }
    }

    @IBOutlet private weak var gradientView: NSView!
    @IBOutlet private weak var flagView: NSImageView!
    @IBOutlet private weak var featureArtView: NSView!
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var descriptionLabel: NSTextField!
    @IBOutlet private weak var upgradeButton: UpsellPrimaryActionButton!
    @IBOutlet private weak var featuresStackView: NSStackView!

    var upsellType: UpsellType?
    private var upsellFeature: UpsellFeature? {
        upsellType?.upsellFeature()
    }

    var upgradeAction: (() -> Void)?
    var continueAction: (() -> Void)?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init() {
        super.init(nibName: NSNib.Name("UpsellView"), bundle: .module)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        view.wantsLayer = true
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background)
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        addGradient()
        setupText()
        setupSubviews()
        setupFeatures()
        upgradeButton.setAccessibilityIdentifier("ModalUpgradeButton")
    }

    func addGradient() {
        guard upsellType?.shouldAddGradient() ?? false else { return }
        let gradientLayer = CAGradientLayer.gradientLayer(in: gradientView.bounds)
        gradientLayer.opacity = 0.4
        gradientView.wantsLayer = true
        gradientView.layer?.addSublayer(gradientLayer)
    }

    func setupSubviews() {
        titleLabel.textColor = .color(.text)

        titleLabel.setAccessibilityIdentifier("TitleLabel")
        descriptionLabel.setAccessibilityIdentifier("DescriptionLabel")
    }

    @objc func setupText() {
        guard let upsellType else { return }
        if upsellType.showUpgradeButton == false {
            switch upsellType {
            case .welcomeFallback, .welcomeUnlimited, .welcomePlus:
                upgradeButton.title = Localizable.modalsCommonGetStarted
            case .cantSkip:
                upgradeButton.title = Localizable.upsellSpecificLocationChangeServerButtonTitle
            default:
                upgradeButton.title = Localizable.modalsGetPlus
            }
        } else {
            upgradeButton.title = Localizable.modalsGetPlus
        }

        guard let upsellFeature else { return }
        titleLabel.stringValue = upsellFeature.title
        if let subtitle = upsellFeature.subtitle {
            descriptionLabel.attributedStringValue = subtitle.attributedString(size: 17,
                                                                               color: .color(.text, .weak),
                                                                               boldStrings: upsellFeature.boldSubtitleElements,
                                                                               alignment: .center)
        } else {
            descriptionLabel.isHidden = true
        }

        if let timeInterval = upsellType
            .changeDate?
            .timeIntervalSince(Date()),
           timeInterval > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) { [weak self] in
                self?.setupText()
            }
        }
    }

    func setupArt(feature: UpsellFeature) {
        let childView = NSHostingController(rootView: AnyView(feature.artImage))
        addChild(childView)
        childView.view.frame = featureArtView.bounds
        childView.view.layer?.backgroundColor = .clear
        featureArtView.addSubview(childView.view)
        childView.view.centerXAnchor.constraint(equalTo: featureArtView.centerXAnchor).isActive = true
        childView.view.centerYAnchor.constraint(equalTo: featureArtView.centerYAnchor).isActive = true
    }

    func setupFeatures() {
        guard let upsellFeature else { return }
        setupArt(feature: upsellFeature)

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
        if upsellType?.showUpgradeButton == false {
            continueAction?()
        } else {
            upgradeAction?()
        }
        dismiss(nil)
    }
}

private extension CAGradientLayer {
    static func gradientLayer(in frame: CGRect) -> Self {
        let layer = Self()
        layer.colors = [NSColor(red: 110.0/255.0,
                                green: 75.0/255.0,
                                blue: 255.0/255.0,
                                alpha: 0).cgColor,
                        NSColor(red: 17.0/255.0,
                                green: 216.0/255.0,
                                blue: 204.0/255.0,
                                alpha: 1).cgColor]
        layer.frame = frame
        return layer
    }
}
