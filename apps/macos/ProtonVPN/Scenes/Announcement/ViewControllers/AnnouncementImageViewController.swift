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
import LegacyCommon
import Ergonomics
import Strings

final class AnnouncementImageViewController: NSViewController {
    @IBOutlet private weak var imageView: NSImageView!
    @IBOutlet private weak var imageViewWidth: NSLayoutConstraint!
    @IBOutlet private weak var imageViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var actionButton: PrimaryActionButton!

    private let data: OfferPanel.ImagePanel
    private let offerReference: String?
    private let sessionService: SessionService

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(data: OfferPanel.ImagePanel, offerReference: String?, sessionService: SessionService) {
        self.data = data
        self.offerReference = offerReference
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

        actionButton.title = data.button.text ?? Localizable.ok
        actionButton.contentTintColor = .color(.icon)

        progressIndicator.startAnimation(nil)
        actionButton.isHidden = true

        imageView.cell?.setAccessibilityElement(true)
        imageView.setAccessibilityLabel(data.fullScreenImage.alternativeText)

        configureImage()
    }

    func configureImage() {
        guard let source = data.fullScreenImage.source.first,
              let imageURL = URL(string: source.url) else {
            log.warning("Couldn't retrieve image URL from data: \(data)")
            view.window?.close()
            return
        }

        imageView.sd_setImage(with: imageURL) { [weak self] image, error, cacheType, url in
            guard error == nil,
                  let image,
                  let self else {
                self?.view.window?.close()
                log.warning("Couldn't retrieve image from URL: \(imageURL)")
                return
            }
            self.progressIndicator.stopAnimation(nil)
            self.actionButton.isHidden = false
            /// Usually `scale` would be 0.5
            let scale = 1 / (NSScreen.main?.backingScaleFactor ?? 1)

            let desiredSize = CGSize(width: CGFloat(source.width ?? image.size.width),
                                     height: CGFloat(source.height ?? image.size.height)) // pixel values

            let imageViewSize = desiredSize.fitting(NSScreen.availableSizeInPixels()) // still in pixels

            // multiply by scale to get point values
            self.imageViewWidth.constant = imageViewSize.width * scale
            self.imageViewHeight.constant = imageViewSize.height * scale

            self.didPresentOffer()
        }
    }

    func didPresentOffer() {
        DispatchQueue.main.async { [offerReference] in
            NotificationCenter.default.post(name: .userWasDisplayedAnnouncement, object: offerReference)
        }
    }

    @IBAction private func didTapActionButton(_ sender: Any) {
        guard data.button.action == .openURL else {
            log.warning("Announcement does not contain <OpenURL> action. Action is <\(data.button.action?.rawValue ?? "nil")>, url: <\(data.button.url)>")
            return
        }

        DispatchQueue.main.async { [offerReference] in
            NotificationCenter.default.post(name: .userEngagedWithAnnouncement, object: offerReference)
        }

        guard data.button.behaviors?.contains(.autoLogin) == true else {
            SafariService().open(url: data.button.url)
            return
        }

        actionButton.isEnabled = false

        Task { [weak actionButton, weak view] in
            // This will retrieve a logged-in session so the user won't have to enter credentials after opening the link
            let url = await sessionService.getUpgradePlanSession(url: data.button.url)
            actionButton?.isEnabled = true
            SafariService().open(url: url)
            view?.window?.close()
        }
    }
}
