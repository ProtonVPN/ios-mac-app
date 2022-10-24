//
//  Created on 23/08/2022.
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
import vpncore
import SDWebImage

final class AnnouncementImageViewController: NSViewController {
    @IBOutlet private weak var imageView: NSImageView!
    @IBOutlet private weak var imageViewWidth: NSLayoutConstraint!
    @IBOutlet private weak var imageViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var actionButton: PrimaryActionButton!

    private let data: OfferPanel.ImagePanel
    private let sessionService: SessionService

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(data: OfferPanel.ImagePanel, sessionService: SessionService) {
        self.data = data
        self.sessionService = sessionService
        super.init(nibName: NSNib.Name(String(describing: AnnouncementImageViewController.self)), bundle: nil)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        view.window?.centerWindowOnScreen()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        actionButton.title = data.button.text
        actionButton.contentTintColor = .color(.icon)

        progressIndicator.startAnimation(nil)
        actionButton.isHidden = true

        imageView.cell?.setAccessibilityElement(true)
        imageView.setAccessibilityLabel(data.fullScreenImage.alternativeText)

        guard let imageURL = data.fullScreenImage.firstURL else {
            // This case should not happen, we're preloading the image before we allow the user to open the announcement
            log.warning("Couldn't retrieve image URL from data: \(data)")
            view.window?.close()
            return
        }
        imageView.sd_setImage(with: imageURL) { [weak self] image, error, cacheType, url in
            guard error == nil else {
                self?.view.window?.close()
                log.warning("Couldn't retrieve image from URL: \(imageURL)")
                return
            }
            self?.progressIndicator.stopAnimation(nil)
            self?.actionButton.isHidden = false
        }
    }

    @IBAction private func didTapActionButton(_ sender: Any) {
        guard data.button.action == .openURL else {
            log.warning("Announcement does not contain <OpenURL> action. Action is <\(data.button.action?.rawValue ?? "nil")>, url: <\(data.button.url)>")
            return
        }

        guard data.button.behaviors?.contains(.autoLogin) == true else {
            SafariService.openLink(url: data.button.url)
            return
        }

        actionButton.isEnabled = false

        // This will retrieve a logged-in session so the user won't have to enter credentials after opening the link
        sessionService.getUpgradePlanSession(url: data.button.url) { [weak actionButton, weak view] url in
            actionButton?.isEnabled = true
            SafariService.openLink(url: url)
            view?.window?.close()
        }
    }
}
