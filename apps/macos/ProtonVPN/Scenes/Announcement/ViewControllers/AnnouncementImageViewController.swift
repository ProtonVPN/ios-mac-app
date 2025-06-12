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

import Dependencies

import LegacyCommon
import CommonNetworking
import VPNAppCore
import Announcement

import Ergonomics
import Strings
import Domain

final class AnnouncementImageViewController: NSViewController {
    @IBOutlet private weak var imageView: NSImageView!
    @IBOutlet private weak var imageViewWidth: NSLayoutConstraint!
    @IBOutlet private weak var imageViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var actionButton: PrimaryActionButton!

    private let data: OfferPanel.ImagePanel
    private let offerReference: String?

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(data: OfferPanel.ImagePanel, offerReference: String?) {
        self.data = data
        self.offerReference = offerReference
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
            progressIndicator.stopAnimation(nil)
            actionButton.isHidden = false
            /// Usually `scale` would be 0.5
            let scale = 1 / (NSScreen.main?.backingScaleFactor ?? 1)

            let desiredSize = CGSize(width: CGFloat(source.width ?? image.size.width),
                                     height: CGFloat(source.height ?? image.size.height)) // pixel values

            let imageViewSize = desiredSize.fitting(NSScreen.availableSizeInPixels()) // still in pixels

            // multiply by scale to get point values
            imageViewWidth.constant = imageViewSize.width * scale
            imageViewHeight.constant = imageViewSize.height * scale

            didPresentOffer()
        }
    }

    func didPresentOffer() {
        DispatchQueue.main.async { [offerReference] in
            AppEvent.userWasDisplayedAnnouncement.post(offerReference)
        }
    }

    @IBAction private func didTapActionButton(_ sender: Any) {
        guard data.button.action == .openURL else {
            log.warning("Announcement does not contain <OpenURL> action. Action is <\(data.button.action?.rawValue ?? "nil")>, url: <\(data.button.url)>")
            return
        }

        DispatchQueue.main.async { [offerReference] in
            AppEvent.userEngagedWithAnnouncement.post(offerReference)
        }

        @Dependency(\.linkOpener) var linkOpener

        guard data.button.behaviors?.contains(.autoLogin) == true else {
            linkOpener.open(data.button.url)
            return
        }

        actionButton.isEnabled = false

        Task { [weak actionButton, weak view] in
            @Dependency(\.sessionService) var sessionService
            // This will retrieve a logged-in session so the user won't have to enter credentials after opening the link
            let url = await sessionService.getUpgradePlanSession(url: data.button.url)
            actionButton?.isEnabled = true
            linkOpener.open(url)
            view?.window?.close()
        }
    }
}
