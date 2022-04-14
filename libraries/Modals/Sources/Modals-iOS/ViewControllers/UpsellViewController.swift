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
import Modals

public protocol UpsellViewControllerDelegate: AnyObject {
    func userDidRequestPlus()

    /// This method exists to allow the parent to decide whether the view controller should dismiss itself or not.
    ///
    /// - Returns: A `Bool` value indicating whether the view controller should dismiss itself.
    ///
    /// - Note: In the onboarding module the parent dismisses the upsell modal. `IosAlertService` allows the upsell to dismiss itself.
    func shouldDismissUpsell() -> Bool
    func userDidDismissUpsell()
    func userDidTapNext()
}

public final class UpsellViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet private weak var featureView: UIView!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var getPlusButton: UIButton!
    @IBOutlet private weak var useFreeButton: UIButton!
    @IBOutlet private weak var featuresStackView: UIStackView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var featuresFooterLabel: UILabel!
    @IBOutlet private weak var featureArtImageView: UIImageView!

    // MARK: Properties

    public weak var delegate: UpsellViewControllerDelegate?

    var upsellType: UpsellType?

    // MARK: Setup

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFeatures()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let topInset = max(0, (scrollView.bounds.height - featureView.bounds.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
    }

    private func setupUI() {
        baseViewStyle(view)
        actionButtonStyle(getPlusButton)
        actionTextButtonStyle(useFreeButton)
        titleStyle(titleLabel)
        subtitleStyle(subtitleLabel)
        footerStyle(featuresFooterLabel)
        switch upsellType {
        case .noLogs:
            getPlusButton.setTitle(LocalizedString.modalsCommonNext, for: .normal)
        default:
            getPlusButton.setTitle(LocalizedString.modalsGetPlus, for: .normal)
        }
        useFreeButton.setTitle(LocalizedString.modalsUpsellStayFree, for: .normal)

        switch upsellType {
        case .noLogs:
            useFreeButton.isHidden = true
        default:
            break
        }

        useFreeButton.accessibilityIdentifier = "UseFreeButton"
        getPlusButton.accessibilityIdentifier = "GetPlusButton"
        titleLabel.accessibilityIdentifier = "TitleLabel"
    }

    func setupFeatures() {
        guard let upsellType = upsellType else { return }
        let upsellFeature = upsellType.upsellFeature()
        titleLabel.text = upsellFeature.title
        if let subtitle = upsellFeature.subtitle {
            subtitleLabel.text = subtitle
        } else {
            subtitleLabel.isHidden = true
        }
        featuresFooterLabel.text = upsellFeature.footer
        featureArtImageView.image = upsellFeature.artImage

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
        switch upsellType {
        case .noLogs:
            delegate?.userDidTapNext()
        default:
            delegate?.userDidRequestPlus()
        }
    }

    @IBAction private func useFreeTapped(_ sender: Any) {
        guard delegate?.shouldDismissUpsell() == true else {
            return
        }
        presentingViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.delegate?.userDidDismissUpsell()
        })
    }

    @objc private func closeTapped() {
        guard delegate?.shouldDismissUpsell() == true else {
            return
        }
        presentingViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.delegate?.userDidDismissUpsell()
        })
    }
}
