//
//  CountryItemCellView.swift
//  ProtonVPN - Created on 27.06.19.
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

import Cocoa
import Ergonomics
import LegacyCommon
import Theme
import SDWebImage
import Strings
import Timer

final class OfferBannerView: NSView {

    @IBOutlet private weak var image: NSImageView!
    @IBOutlet private weak var roundedBackgroundView: NSView!
    @IBOutlet private weak var label: NSTextField!
    @IBOutlet private weak var separatorViewBottom: NSView!
    @IBOutlet var dismissButton: NSButton!

    private var viewModel: OfferBannerViewModel!

    var timer: BackgroundTimer?

    var sessionService: SessionService?

    override func awakeFromNib() {
        super.awakeFromNib()

        dismissButton.image = Theme.Asset.dismissButton.image
        roundedBackgroundView.wantsLayer = true
        roundedBackgroundView.layer?.cornerRadius = 8
        DarkAppearance {
            roundedBackgroundView.layer?.backgroundColor = .cgColor(.background, [.strong])
            roundedBackgroundView.layer?.borderWidth = 1
            roundedBackgroundView.layer?.borderColor = .cgColor(.border)
        }

        label.wantsLayer = true
        label.textColor = .color(.text, [.weak])
        label.font = .themeFont(.small)

        separatorViewBottom.wantsLayer = true
        DarkAppearance {
            separatorViewBottom.layer?.backgroundColor = .cgColor(.border, .weak)
        }
    }

    func updateView(withModel viewModel: OfferBannerViewModel) {
        self.viewModel = viewModel
        timer?.invalidate()
        timer = viewModel.createTimer(updateTimeRemaining: updateTimeRemaining)

        if let image = SDImageCache.shared.imageFromCache(forKey: viewModel.imageURL.absoluteString) {
            self.image.image = image
            return
        }
        SDWebImageDownloader.shared.downloadImage(with: viewModel.imageURL) { [weak self] image, _, _, _ in
            if let image {
                SDImageCache.shared.store(image, forKey: viewModel.imageURL.absoluteString, completion: nil)
                self?.image.image = image
            }
        }
    }

    func updateTimeRemaining() {
        guard let viewModel else { return }
        label.isHidden = !viewModel.showCountdown
        guard let text = viewModel.timeLeftString() else {
            timer?.invalidate()
            viewModel.dismiss()
            return
        }
        label.stringValue = text
    }

    // MARK: - Actions

    @IBAction private func didTap(_ sender: Any) {
        guard let sessionService else { return }
        Task {
            await viewModel.action(sessionService)
        }
    }

    @IBAction private func didDismiss(_ sender: Any) {
        viewModel.dismiss()
    }

    // MARK: - Mouse hovering

    override func resetCursorRects() {
        addCursorRect(roundedBackgroundView.frame, cursor: .pointingHand)
        addCursorRect(dismissButton.frame, cursor: .pointingHand)
    }
}
