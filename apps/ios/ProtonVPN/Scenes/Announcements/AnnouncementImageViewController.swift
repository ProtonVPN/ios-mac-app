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

final class AnnouncementImageViewController: AnnouncementViewController {

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var actionButton: UIButton!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var imageViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var progressIndicator: UIActivityIndicatorView!

    private let data: OfferPanel.ImagePanel

    var didShowTheWholeModal = false

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(_ data: OfferPanel.ImagePanel) {
        self.data = data
        super.init(nibName: String(describing: AnnouncementImageViewController.self), bundle: nil)
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
        closeButton.setImage(closeButton.imageView?.image?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeButton.tintColor = .normalTextColor()
        actionButton.setTitle(data.button.text, for: .normal)

        setupImage()
    }

    private func setupImage() {
        guard let imageURL = data.fullScreenImage.preferredSource() else {
            // close window or present an error message
            return
        }
        progressIndicator.startAnimating()
        actionButton.isHidden = true

        imageView.sd_setImage(with: imageURL) { [weak self] image, error, cacheType, url in
            guard error == nil else {
                // close window or present an error message or open browser
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

    @IBAction private func actionButtonTapped(_ sender: Any) {
        urlRequested?(data.button.url)
    }

    @IBAction private func closeButtonTapped(_ sender: Any) {
        cancelled?()
    }
}
