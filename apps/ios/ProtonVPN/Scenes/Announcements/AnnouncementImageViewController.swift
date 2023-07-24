//
//  Created on 26/08/2022.
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
import vpncore
import Alamofire
import SDWebImage
import ProtonCoreUIFoundations

final class AnnouncementImageViewController: AnnouncementViewController {

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var actionButton: UIButton!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var imageViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var progressIndicator: UIActivityIndicatorView!

    private let data: OfferPanel.ImagePanel

    var didShowTheWholeModal = false

    private let sessionService: SessionService

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(data: OfferPanel.ImagePanel, sessionService: SessionService) {
        self.data = data
        self.sessionService = sessionService
        super.init(nibName: String(describing: AnnouncementImageViewController.self), bundle: nil)
    }

    deinit {
        getUpgradePlanSessionTask?.cancel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustImageViewHeight()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToBottomWithDelay()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .backgroundColor()
        closeButton.setImage(IconProvider.crossBig, for: .normal)
        closeButton.tintColor = .normalTextColor()
        actionButton.setTitle(data.button.text, for: .normal)

        setupImage()
    }

    private func setupImage() {
        guard let imageURL = data.fullScreenImage.firstURL else {
            // This case should not happen, we're preloading the image before we allow the user to open the announcement
            log.warning("Couldn't retrieve image URL from data: \(data)")
            cancelled?()
            return
        }
        progressIndicator.startAnimating()
        actionButton.isHidden = true

        imageView.accessibilityLabel = data.fullScreenImage.alternativeText
        imageView.isAccessibilityElement = true

        imageView.sd_setImage(with: imageURL) { [weak self] image, error, cacheType, url in
            guard error == nil else {
                self?.cancelled?()
                log.warning("Couldn't retrieve image from URL: \(imageURL)")
                return
            }
            self?.progressIndicator.stopAnimating()
            self?.actionButton.isHidden = false
        }
    }

    private func adjustImageViewHeight() {
        guard let image = imageView.image else { return }
        let imageRatio = image.size.height / image.size.width
        let height = imageView.frame.size.width * imageRatio
        imageViewHeight.constant = height
    }

    private func scrollToBottomWithDelay() {
        let yOffset = imageViewHeight.constant - scrollView.frame.height
        guard yOffset > 0 else {
            didShowTheWholeModal = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard self?.didShowTheWholeModal == false else {
                return
            }
            self?.didShowTheWholeModal = true
            self?.scrollView?.setContentOffset(CGPoint(x: 0, y: yOffset), animated: true)
        }
    }

    var getUpgradePlanSessionTask: Task<Void, Never>?

    @IBAction private func actionButtonTapped(_ sender: Any) {
        guard data.button.action == .openURL else {
            log.warning("Announcement does not contain <OpenURL> action. Action is <\(data.button.action?.rawValue ?? "nil")>, url: <\(data.button.url)>")
            cancelled?()
            return
        }

        guard data.button.behaviors?.contains(.autoLogin) == true else {
            urlRequested?(data.button.url)
            cancelled?()
            return
        }

        actionButton.isEnabled = false

        getUpgradePlanSessionTask = Task {
            // This will retrieve a logged-in session so the user won't have to enter credentials after opening the link
            let url = await sessionService.getUpgradePlanSession(url: data.button.url)
            guard getUpgradePlanSessionTask?.isCancelled == false else { return }
            actionButton.isEnabled = true
            urlRequested?(url)
            cancelled?()
            getUpgradePlanSessionTask = nil
        }
    }

    @IBAction private func closeButtonTapped(_ sender: Any) {
        getUpgradePlanSessionTask?.cancel()
        cancelled?()
    }
}
