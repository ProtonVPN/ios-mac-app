//
//  Created on 09/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Cocoa
import Ergonomics
import PaymentsShared
import Strings
import SwiftUI
import Theme

public final class UpsellViewController: NSViewController {
    private lazy var borderView: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var gradientView: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        return view
    }()

    private lazy var featureArtView: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var featuresContainerView: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        return view
    }()

    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .color(.text)
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.font = .systemFont(ofSize: 22)
        label.setAccessibilityIdentifier("TitleLabel")
        return label
    }()

    private lazy var descriptionLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setAccessibilityIdentifier("DescriptionLabel")
        return label
    }()

    private lazy var upgradeButton: UpsellPrimaryActionButton = {
        let button = UpsellPrimaryActionButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .regularSquare
        button.horizontalPadding = Dimensions.buttonHorizontalPadding
        button.target = self
        button.action = #selector(upgrade(_:))
        button.setAccessibilityIdentifier("ModalUpgradeButton")
        return button
    }()

    private lazy var featuresStackView: NSStackView = {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Dimensions.featuresStackSpacing
        return stack
    }()

    private var gradientLayer: CAGradientLayer?
    private var artHostingController: NSHostingController<AnyView>?

    var modalType: UpsellModalType

    var upgradeAction: (() -> Void)?
    var continueAction: (() -> Void)?

    // MARK: - Init

    public init(modalType: UpsellModalType, upgradeAction: (() -> Void)?, continueAction: (() -> Void)?) {
        self.modalType = modalType
        self.upgradeAction = upgradeAction
        self.continueAction = continueAction
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadView() {
        view = NSView()
        view.wantsLayer = true
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background)
        }

        view.addSubview(borderView)
        borderView.addSubview(gradientView)
        borderView.addSubview(featureArtView)
        borderView.addSubview(titleLabel)
        borderView.addSubview(descriptionLabel)
        borderView.addSubview(featuresContainerView)
        featuresContainerView.addSubview(featuresStackView)
        borderView.addSubview(upgradeButton)

        NSLayoutConstraint.activate([
            borderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            borderView.topAnchor.constraint(equalTo: view.topAnchor),
            borderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            gradientView.leadingAnchor.constraint(equalTo: borderView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: borderView.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: borderView.topAnchor),
            gradientView.heightAnchor.constraint(equalToConstant: Dimensions.gradientHeight),

            featureArtView.centerXAnchor.constraint(equalTo: borderView.centerXAnchor),
            featureArtView.topAnchor.constraint(equalTo: borderView.topAnchor, constant: Dimensions.featureArtTopPadding),
            featureArtView.widthAnchor.constraint(equalToConstant: Dimensions.featureArtWidth),
            featureArtView.heightAnchor.constraint(equalToConstant: Dimensions.featureArtHeight),

            titleLabel.topAnchor.constraint(equalTo: featureArtView.bottomAnchor, constant: Dimensions.titleTopSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: borderView.leadingAnchor, constant: Dimensions.horizontalContentPadding),
            titleLabel.trailingAnchor.constraint(equalTo: borderView.trailingAnchor, constant: -Dimensions.horizontalContentPadding),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Dimensions.subtitleTopSpacing),
            descriptionLabel.leadingAnchor.constraint(equalTo: borderView.leadingAnchor, constant: Dimensions.horizontalContentPadding),
            descriptionLabel.trailingAnchor.constraint(equalTo: borderView.trailingAnchor, constant: -Dimensions.horizontalContentPadding),

            featuresContainerView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: Dimensions.featuresTopSpacing),
            featuresContainerView.centerXAnchor.constraint(equalTo: borderView.centerXAnchor),
            featuresContainerView.widthAnchor.constraint(greaterThanOrEqualToConstant: Dimensions.featureBoxMinWidth),
            featuresContainerView.leadingAnchor.constraint(greaterThanOrEqualTo: borderView.leadingAnchor, constant: Dimensions.minFeatureBoxHorizontalMargin),
            featuresContainerView.trailingAnchor.constraint(lessThanOrEqualTo: borderView.trailingAnchor, constant: -Dimensions.minFeatureBoxHorizontalMargin),

            featuresStackView.topAnchor.constraint(equalTo: featuresContainerView.topAnchor, constant: Dimensions.featureBoxVerticalPadding),
            featuresStackView.leadingAnchor.constraint(equalTo: featuresContainerView.leadingAnchor, constant: Dimensions.featureBoxHorizontalPadding),
            featuresStackView.trailingAnchor.constraint(equalTo: featuresContainerView.trailingAnchor, constant: -Dimensions.featureBoxHorizontalPadding),
            featuresStackView.bottomAnchor.constraint(equalTo: featuresContainerView.bottomAnchor, constant: -Dimensions.featureBoxVerticalPadding),

            upgradeButton.topAnchor.constraint(greaterThanOrEqualTo: featuresContainerView.bottomAnchor, constant: Dimensions.buttonTopSpacing),
            upgradeButton.topAnchor.constraint(greaterThanOrEqualTo: descriptionLabel.bottomAnchor, constant: Dimensions.buttonTopSpacing),
            upgradeButton.centerXAnchor.constraint(equalTo: borderView.centerXAnchor),
            upgradeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: Dimensions.buttonWidth),
            upgradeButton.leadingAnchor.constraint(greaterThanOrEqualTo: borderView.leadingAnchor, constant: Dimensions.minButtonHorizontalMargin),
            upgradeButton.trailingAnchor.constraint(lessThanOrEqualTo: borderView.trailingAnchor, constant: -Dimensions.minButtonHorizontalMargin),
            upgradeButton.bottomAnchor.constraint(equalTo: borderView.bottomAnchor, constant: -Dimensions.bottomContentPadding),
            upgradeButton.heightAnchor.constraint(equalToConstant: Dimensions.buttonHeight),
        ])
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        applyFeaturesContainerStyle()
        setupText()
        setupFeatures()
    }

    override public func viewDidLayout() {
        super.viewDidLayout()
        applyFeaturesContainerStyle()
        updateGradient()
    }

    override public func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyUpsellModalAppearance()
        applyFeaturesContainerStyle()
    }

    private func applyFeaturesContainerStyle() {
        featuresContainerView.wantsLayer = true
        guard let layer = featuresContainerView.layer else { return }
        layer.backgroundColor = NSColor.clear.cgColor
        layer.cornerRadius = .themeRadius12
        layer.borderWidth = 1
        layer.masksToBounds = true
        DarkAppearance {
            layer.borderColor = NSColor.color(.border).cgColor
        }
    }

    func updateGradient() {
        let layer = gradientLayer ?? CAGradientLayer.gradientLayer(in: gradientView.bounds)
        layer.frame = gradientView.bounds
        layer.opacity = Dimensions.gradientOpacity
        if gradientLayer == nil {
            gradientView.layer?.addSublayer(layer)
            gradientLayer = layer
        }
    }

    @objc
    func setupText() {
        if modalType.showUpgradeButton == false {
            switch modalType {
            case .cantSkip:
                upgradeButton.title = Localizable.upsellSpecificLocationChangeServerButtonTitle
            default:
                upgradeButton.title = Localizable.modalsGetPlus
            }
        } else {
            upgradeButton.title = Localizable.modalsGetPlus
        }

        titleLabel.stringValue = modalType.title
        if let subtitle = modalType.subtitleModel {
            descriptionLabel.attributedStringValue = subtitle.text.attributedString(
                size: 17,
                color: .color(.text, .weak),
                boldStrings: subtitle.boldText,
                alignment: .center
            )
        } else {
            descriptionLabel.isHidden = true
        }

        if let timeInterval = modalType
            .changeDate?
            .timeIntervalSince(Date()),
            timeInterval > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) { [weak self] in
                self?.setupText()
            }
        }
    }

    func setupArt(type: UpsellModalType) {
        artHostingController?.view.removeFromSuperview()
        artHostingController?.removeFromParent()

        let childView = NSHostingController(rootView: AnyView(type.artImage()))
        childView.view.translatesAutoresizingMaskIntoConstraints = false
        childView.view.layer?.backgroundColor = .clear
        addChild(childView)
        featureArtView.addSubview(childView.view)

        NSLayoutConstraint.activate([
            childView.view.leadingAnchor.constraint(equalTo: featureArtView.leadingAnchor),
            childView.view.trailingAnchor.constraint(equalTo: featureArtView.trailingAnchor),
            childView.view.topAnchor.constraint(equalTo: featureArtView.topAnchor),
            childView.view.bottomAnchor.constraint(equalTo: featureArtView.bottomAnchor),
        ])
        artHostingController = childView
    }

    func setupFeatures() {
        setupArt(type: modalType)

        for view in featuresStackView.arrangedSubviews {
            view.removeFromSuperview()
        }

        guard !modalType.features().isEmpty else {
            featuresContainerView.isHidden = true
            return
        }
        featuresContainerView.isHidden = false

        for feature in modalType.features() {
            let view = UpsellFeatureView()
            view.feature = feature
            featuresStackView.addArrangedSubview(view)
        }
    }

    @IBAction
    private func upgrade(_: Any) {
        if modalType.showUpgradeButton == false {
            continueAction?()
        } else {
            upgradeAction?()
        }
        dismiss(nil)
    }
}

extension UpsellViewController {
    private enum Dimensions {
        static let horizontalContentPadding: CGFloat = 60
        static let bottomContentPadding: CGFloat = 64

        static let gradientHeight: CGFloat = 300
        static let gradientOpacity: Float = 0.4

        static let featureArtTopPadding: CGFloat = 64
        static let featureArtWidth: CGFloat = 400
        static let featureArtHeight: CGFloat = 184

        static let titleTopSpacing: CGFloat = 8
        static let subtitleTopSpacing: CGFloat = 8
        static let featuresTopSpacing: CGFloat = 32
        static let featureBoxVerticalPadding: CGFloat = 16
        static let featureBoxHorizontalPadding: CGFloat = 24
        static let featureBoxMinWidth: CGFloat = 250
        static let minFeatureBoxHorizontalMargin: CGFloat = 80
        static let featuresStackSpacing: CGFloat = 12

        static let buttonTopSpacing: CGFloat = 32
        static let buttonWidth: CGFloat = 125
        static let buttonHeight: CGFloat = 46
        static let buttonHorizontalPadding: CGFloat = 48
        static let minButtonHorizontalMargin: CGFloat = 100
    }
}

private extension CAGradientLayer {
    static func gradientLayer(in frame: CGRect) -> Self {
        let layer = Self()
        layer.colors = [
            NSColor(
                red: 110.0 / 255.0,
                green: 75.0 / 255.0,
                blue: 255.0 / 255.0,
                alpha: 0
            ).cgColor,
            NSColor(
                red: 17.0 / 255.0,
                green: 216.0 / 255.0,
                blue: 204.0 / 255.0,
                alpha: 1
            ).cgColor,
        ]
        layer.frame = frame
        return layer
    }
}
