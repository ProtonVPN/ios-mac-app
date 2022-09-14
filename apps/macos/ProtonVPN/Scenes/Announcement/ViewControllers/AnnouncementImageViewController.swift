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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(_ data: OfferPanel.ImagePanel) {
        self.data = data
        super.init(nibName: NSNib.Name(String(describing: AnnouncementImageViewController.self)), bundle: nil)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        view.window?.centerWindowOnScreen()

//        adjustImageViewHeight()
    }

//    private func adjustImageViewHeight() {
//        guard let image = imageView.image else { return }
//        let imageRatio = image.size.height / image.size.width
//        let height = imageView.frame.size.width * imageRatio
//        imageViewHeight.constant = height
//    }

    override func viewDidLoad() {
        super.viewDidLoad()

        actionButton.title = data.button.text
        actionButton.contentTintColor = .color(.icon)

        progressIndicator.startAnimation(nil)
        actionButton.isHidden = true

        guard let imageURL = data.fullScreenImage.preferredSource() else {
            // close window or present an error message
            return
        }
        imageView.sd_setImage(with: imageURL) { [weak self] image, error, cacheType, url in
            guard error == nil else {
                // close window or present an error message or open browser
                return
            }
            self?.progressIndicator.stopAnimation(nil)
            self?.actionButton.isHidden = false
        }
    }

    @IBAction private func didTapActionButton(_ sender: Any) {
        SafariService.openLink(url: data.button.url)
    }
}
