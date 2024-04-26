//
//  OneLineTableViewCell.swift
//  ProtonVPN - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import UIKit
import Theme
import LegacyCommon
import SDWebImage
import Strings
import Timer
import Ergonomics

class OfferBannerViewCell: UITableViewCell {

    @IBOutlet weak var roundedBackgroundView: RoundedBackgroundView!
    @IBOutlet weak var offerImageView: UIImageView!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    @IBOutlet weak var dismissButton: UIButton! {
        didSet {
            dismissButton.setImage(Theme.Asset.dismissButton.image, for: .normal)
            dismissButton.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        }
    }

    var viewModel: OfferBannerViewModel? {
        didSet {
            updateView()
        }
    }

    var timer: BackgroundTimer?

    @IBAction func dismissButtonTapped(_ sender: UIButton) {
        timer?.invalidate()
        viewModel?.dismiss()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = .color(.background)
        timeRemainingLabel.textColor = .color(.text, .weak)
        timeRemainingLabel.font = .systemFont(ofSize: 13)

        selectionStyle = .none
    }

    func updateView() {
        guard let viewModel else { return }
        timer?.invalidate()
        timer = viewModel.createTimer(updateTimeRemaining: updateTimeRemaining)

        if let image = SDImageCache.shared.imageFromCache(forKey: viewModel.imageURL.absoluteString) {
            self.offerImageView.image = image
            return
        }
        SDWebImageDownloader.shared.downloadImage(with: viewModel.imageURL) { [weak self] image, _, _, _ in
            if let image {
                SDImageCache.shared.store(image, forKey: viewModel.imageURL.absoluteString, completion: nil)
                self?.offerImageView.image = image
            }
        }
    }

    func updateTimeRemaining() {
        guard let viewModel else { return }
        timeRemainingLabel.isHidden = !viewModel.showCountdown
        guard let text = viewModel.timeLeftString() else {
            timer?.invalidate()
            viewModel.dismiss()
            return
        }
        timeRemainingLabel.text = text
    }
}

class RoundedBackgroundView: UIView {

    let colors = [Theme.Asset.offerBannerGradientLeft.color,
                  Theme.Asset.offerBannerGradientRight.color]

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .color(.background, .weak)
        layer.cornerRadius = .themeRadius12
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.gradientBorder(colors: colors,
                             startPoint: .CoordinateSpace.left,
                             endPoint: .CoordinateSpace.right,
                             andRoundCornersWithRadius: .themeRadius12)
    }
}
