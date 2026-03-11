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
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        DarkAppearance {
            view.layer?.borderColor = NSColor.color(.border).cgColor
        }
        view.layer?.cornerRadius = .themeRadius12
        view.layer?.borderWidth = 1
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

    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .color(.text)
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.font = .systemFont(ofSize: 28, weight: .semibold)
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
        stack.spacing = 12
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
        borderView.addSubview(featuresStackView)
        borderView.addSubview(upgradeButton)

        NSLayoutConstraint.activate([
            borderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Dimensions.outerPadding),
            borderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Dimensions.outerPadding),
            borderView.topAnchor.constraint(equalTo: view.topAnchor, constant: Dimensions.outerPadding),
            borderView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Dimensions.outerPadding),

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

            featuresStackView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: Dimensions.featuresTopSpacing),
            featuresStackView.leadingAnchor.constraint(equalTo: borderView.leadingAnchor, constant: Dimensions.horizontalContentPadding),
            featuresStackView.trailingAnchor.constraint(equalTo: borderView.trailingAnchor, constant: -Dimensions.horizontalContentPadding),

            upgradeButton.topAnchor.constraint(greaterThanOrEqualTo: featuresStackView.bottomAnchor, constant: Dimensions.buttonTopSpacing),
            upgradeButton.leadingAnchor.constraint(equalTo: borderView.leadingAnchor, constant: Dimensions.horizontalContentPadding),
            upgradeButton.trailingAnchor.constraint(equalTo: borderView.trailingAnchor, constant: -Dimensions.horizontalContentPadding),
            upgradeButton.bottomAnchor.constraint(equalTo: borderView.bottomAnchor, constant: -Dimensions.bottomContentPadding),
            upgradeButton.heightAnchor.constraint(equalToConstant: Dimensions.buttonHeight),
        ])
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupText()
        setupFeatures()
    }

    override public func viewDidLayout() {
        super.viewDidLayout()
        updateGradient()
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
            childView.view.centerXAnchor.constraint(equalTo: featureArtView.centerXAnchor),
            childView.view.centerYAnchor.constraint(equalTo: featureArtView.centerYAnchor),
            childView.view.leadingAnchor.constraint(greaterThanOrEqualTo: featureArtView.leadingAnchor),
            childView.view.trailingAnchor.constraint(lessThanOrEqualTo: featureArtView.trailingAnchor),
            childView.view.topAnchor.constraint(greaterThanOrEqualTo: featureArtView.topAnchor),
            childView.view.bottomAnchor.constraint(lessThanOrEqualTo: featureArtView.bottomAnchor),
        ])
        artHostingController = childView
    }

    func setupFeatures() {
        setupArt(type: modalType)

        for view in featuresStackView.arrangedSubviews {
            view.removeFromSuperview()
        }

        guard !modalType.features().isEmpty else {
            featuresStackView.isHidden = true
            return
        }
        featuresStackView.isHidden = false

        for feature in modalType.features() {
            let view = UpsellFeatureView()
            view.feature = feature
            featuresStackView.addArrangedSubview(view)
        }
    }

    override public func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyUpsellModalAppearance()
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
        static let outerPadding: CGFloat = 24
        static let horizontalContentPadding: CGFloat = 24
        static let bottomContentPadding: CGFloat = 24

        static let gradientHeight: CGFloat = 220
        static let gradientOpacity: Float = 0.4

        static let featureArtTopPadding: CGFloat = 24
        static let featureArtWidth: CGFloat = 180
        static let featureArtHeight: CGFloat = 120

        static let titleTopSpacing: CGFloat = 20
        static let subtitleTopSpacing: CGFloat = 12
        static let featuresTopSpacing: CGFloat = 20
        static let buttonTopSpacing: CGFloat = 20
        static let buttonHeight: CGFloat = 44
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
