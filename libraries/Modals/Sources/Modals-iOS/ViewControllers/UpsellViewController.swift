//
//  Created on 10.01.2022.
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

import Foundation
import UIKit
import SwiftUI
import Modals
import Strings
import Theme

public protocol UpsellViewControllerDelegate: AnyObject {
    func userDidRequestPlus(upsell: UpsellViewController?)

    /// This method exists to allow the parent to decide whether the view controller should dismiss itself or not.
    ///
    /// - Returns: A `Bool` value indicating whether the view controller should dismiss itself.
    ///
    /// - Note: In the onboarding module the parent dismisses the upsell modal. `IosAlertService` allows the upsell to dismiss itself.
    func shouldDismissUpsell(upsell: UpsellViewController?) -> Bool
    func userDidDismissUpsell(upsell: UpsellViewController?)
    func userDidTapNext(upsell: UpsellViewController)
    func upsellDidDisappear(upsell: UpsellViewController?)
}

public final class UpsellViewController: UIViewController, Identifiable {
    public let id = UUID()

    // MARK: Outlets

    @IBOutlet private weak var borderView: UIView! {
        didSet {
            borderView.backgroundColor = .clear
            borderView.layer.borderColor = UIColor.color(.border).cgColor
            borderView.layer.cornerRadius = .themeRadius12
            borderView.layer.borderWidth = 1
        }
    }

    let gradientLayer = CAGradientLayer.gradientLayer()
    @IBOutlet private weak var gradientView: UIView!
    @IBOutlet private weak var featureView: UIView!
    @IBOutlet private weak var scrollView: CenteringScrollView!
    @IBOutlet private weak var getPlusButton: UIButton!
    @IBOutlet private weak var useFreeButton: UIButton!
    @IBOutlet private weak var featuresStackView: UIStackView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var featureArtView: UIView!

    // MARK: Properties

    public weak var delegate: UpsellViewControllerDelegate?

    var upsellType: UpsellType?

    // MARK: Setup

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFeatures()
        setupTitleLabels()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        delegate?.upsellDidDisappear(upsell: self)
    }

    public override func viewDidLayoutSubviews() {
        layoutGradient()
    }

    private func setupUI() {
        baseViewStyle(view)
        actionButtonStyle(getPlusButton)
        actionTextButtonStyle(useFreeButton)
        titleStyle(titleLabel)
        subtitleStyle(subtitleLabel)

        if upsellType?.showUpgradeButton == false {
            useFreeButton.isHidden = true
            switch upsellType {
            case .noLogs:
                getPlusButton.setTitle(Localizable.modalsCommonNext, for: .normal)
            case .cantSkip:
                getPlusButton.setTitle(Localizable.upsellSpecificLocationChangeServerButtonTitle, for: .normal)
            default:
                break
            }
        } else {
            getPlusButton.setTitle(Localizable.modalsGetPlus, for: .normal)
        }
        useFreeButton.setTitle(Localizable.modalsUpsellStayFree, for: .normal)

        useFreeButton.accessibilityIdentifier = "UseFreeButton"
        getPlusButton.accessibilityIdentifier = "GetPlusButton"
        titleLabel.accessibilityIdentifier = "TitleLabel"

        if let timeInterval = upsellType?
            .changeDate?
            .timeIntervalSince(Date()),
           timeInterval > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) { [weak self] in
                self?.setupTitleLabels()
                self?.setupUI()
            }
        }
    }

    func layoutGradient() {
        guard upsellType?.shouldAddGradient() == true else { return }
        guard gradientView.layer.sublayers?.contains(gradientLayer) != true else {
            gradientLayer.frame = gradientView.frame
            return
        }
        gradientView.layer.addSublayer(gradientLayer)
    }

    func setupTitleLabels() {
        guard let upsellType = upsellType else { return }
        let upsellFeature = upsellType.upsellFeature()
        titleLabel.text = upsellFeature.title
        if let subtitle = upsellFeature.subtitle {
            subtitleLabel.attributedText =
            subtitle.attributedString(size: 17,
                                      color: UIColor.color(.text, .weak),
                                      boldStrings: upsellFeature.boldSubtitleElements)
        } else {
            subtitleLabel.isHidden = true
        }
    }

    func setupFeatures() {
        guard let upsellType = upsellType else { return }
        let upsellFeature = upsellType.upsellFeature()

        applyArtView(feature: upsellFeature)

        borderView.isHidden = upsellFeature.features.isEmpty

        for view in featuresStackView.arrangedSubviews {
            view.removeFromSuperview()
            featuresStackView.removeArrangedSubview(view)
        }

        for feature in upsellFeature.features {
            if let view = Bundle.module.loadNibNamed("FeatureView", owner: self, options: nil)?.first as? FeatureView {
                view.feature = feature
                featuresStackView.addArrangedSubview(view)
            }
        }

        if let feature = upsellType.upsellFeature().moreInformation {
            if let view = Bundle.module.loadNibNamed("MoreInformationView", owner: self, options: nil)?.first as? MoreInformationView {
                view.feature = feature
                featuresStackView.addArrangedSubview(view)
            }
        }

        let closeButtonImage = UpsellFeature.closeButton()
        let closeButton = UIBarButtonItem(image: closeButtonImage, style: .plain, target: self, action: #selector(closeTapped))
        closeButton.accessibilityIdentifier = "CloseButton"
        navigationItem.leftBarButtonItem = closeButton
    }

    // MARK: Actions

    @IBAction private func getPlusTapped(_ sender: Any) {
        if upsellType?.showUpgradeButton == false {
            delegate?.userDidTapNext(upsell: self)
        } else {
            delegate?.userDidRequestPlus(upsell: self)
        }
    }

    @IBAction private func useFreeTapped(_ sender: Any) {
        guard delegate?.shouldDismissUpsell(upsell: self) == true else {
            return
        }
        presentingViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.delegate?.userDidDismissUpsell(upsell: self)
        })
    }

    @objc private func closeTapped() {
        guard delegate?.shouldDismissUpsell(upsell: self) == true else {
            return
        }
        presentingViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.delegate?.userDidDismissUpsell(upsell: self)
        })
    }

    private func applyArtView(feature: UpsellFeature) {
        let childView = UIHostingController(rootView: AnyView(feature.artImage))
        addChild(childView)
        childView.view.frame = featureArtView.bounds
        childView.view.backgroundColor = .clear
        featureArtView.addSubview(childView.view)
        childView.view.centerXAnchor.constraint(equalTo: featureArtView.centerXAnchor).isActive = true
        childView.view.centerYAnchor.constraint(equalTo: featureArtView.centerYAnchor).isActive = true
        childView.didMove(toParent: self)
    }
}

private extension UIImage {
    func mergedOnTop(with otherImage: UIImage?) -> UIImage? {
        guard let otherImage else { return self }
        let flagSize = CGSize(width: 48, height: 48)
        let origin = CGPoint(x: ((size.width - flagSize.width) / 2), y: ((size.height - flagSize.height) / 2))
        let bounds = CGRect(origin: origin, size: flagSize)

        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        self.draw(in: CGRect(origin: .zero, size: size))
        otherImage.draw(in: bounds)
        let mergedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return mergedImage
    }
}

private extension CAGradientLayer {
    static func gradientLayer() -> Self {
        let layer = Self()
        layer.opacity = 0.4
        layer.colors = [UIColor(red: 17.0/255.0,
                                green: 216.0/255.0,
                                blue: 204.0/255.0,
                                alpha: 1).cgColor,
                        UIColor(red: 110.0/255.0,
                                green: 75.0/255.0,
                                blue: 255.0/255.0,
                                alpha: 0).cgColor]
        return layer
    }
}
