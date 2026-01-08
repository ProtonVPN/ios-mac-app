//
//  OfferBannerViewCell.swift
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

import Announcement
import Ergonomics
import LegacyCommon
import SDWebImage
import Strings
import Theme
import Timer
import UIKit

class OfferBannerViewCell: UITableViewCell {
    private let roundedBackgroundView: RoundedBackgroundView = {
        let view = RoundedBackgroundView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let offerImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()

    private let timeRemainingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .color(.text, .weak)
        label.font = .systemFont(ofSize: Dimensions.labelFontSize)
        return label
    }()

    private let dismissButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(Theme.Asset.dismissButton.image, for: .normal)
        return button
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .leading
        return stackView
    }()

    var viewModel: OfferBannerViewModel? {
        didSet {
            updateView()
        }
    }

    var timerTask: Task<Void, Error>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .color(.background)
        selectionStyle = .none

        contentView.addSubview(roundedBackgroundView)
        contentView.addSubview(dismissButton)
        roundedBackgroundView.addSubview(stackView)

        stackView.addArrangedSubview(offerImageView)
        stackView.addArrangedSubview(timeRemainingLabel)

        dismissButton.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            // Rounded background view constraints
            roundedBackgroundView.topAnchor
                .constraint(equalTo: contentView.topAnchor, constant: Dimensions.RoundedBackgroundView.topMargin),
            roundedBackgroundView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            roundedBackgroundView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            roundedBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Dimensions.RoundedBackgroundView.bottomMargin),

            // Stack view constraints
            stackView.topAnchor.constraint(equalTo: roundedBackgroundView.topAnchor, constant: Dimensions.StackView.verticalPadding),
            stackView.leadingAnchor.constraint(equalTo: roundedBackgroundView.leadingAnchor, constant: Dimensions.StackView.horizontalPadding),
            stackView.trailingAnchor.constraint(equalTo: roundedBackgroundView.trailingAnchor, constant: -Dimensions.StackView.horizontalPadding),
            stackView.bottomAnchor.constraint(equalTo: roundedBackgroundView.bottomAnchor, constant: -Dimensions.StackView.verticalPadding),

            // Dismiss button positioned at top-right corner
            dismissButton.centerXAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Dimensions.DismissButton.trailingOffset),
            dismissButton.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: Dimensions.DismissButton.topOffset),
            dismissButton.widthAnchor.constraint(equalToConstant: Dimensions.DismissButton.width),
            dismissButton.heightAnchor.constraint(equalToConstant: Dimensions.DismissButton.height),
        ])

        // Set content hugging priorities
        timeRemainingLabel.setContentHuggingPriority(.required, for: .vertical)
        timeRemainingLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @objc
    func dismissButtonTapped(_: UIButton) {
        timerTask?.cancel()
        timerTask = nil
        viewModel?.dismiss()
    }

    func updateView() {
        guard let viewModel else { return }
        timerTask?.cancel()
        timerTask = viewModel.createTimer(updateTimeRemaining: updateTimeRemaining)

        if let image = SDImageCache.shared.imageFromCache(forKey: viewModel.imageURL.absoluteString) {
            offerImageView.image = image
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
            timerTask?.cancel()
            timerTask = nil
            viewModel.dismiss()
            return
        }
        timeRemainingLabel.text = text
    }
}

extension OfferBannerViewCell {
    private enum Dimensions {
        enum RoundedBackgroundView {
            static let topMargin: CGFloat = 18
            static let bottomMargin: CGFloat = 8
        }

        enum StackView {
            static let horizontalPadding: CGFloat = 16
            static let verticalPadding: CGFloat = 12
        }

        enum DismissButton {
            static let width: CGFloat = 52
            static let height: CGFloat = 42
            static let trailingOffset: CGFloat = 22
            static let topOffset: CGFloat = 22
        }

        static let labelFontSize: CGFloat = 13
    }
}

class RoundedBackgroundView: UIView {
    let colors = [
        Theme.Asset.offerBannerGradientLeft.color,
        Theme.Asset.offerBannerGradientRight.color,
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = .color(.background, .weak)
        layer.cornerRadius = .themeRadius12
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.gradientBorder(
            colors: colors,
            startPoint: .CoordinateSpace.left,
            endPoint: .CoordinateSpace.right,
            andRoundCornersWithRadius: .themeRadius12
        )
    }
}
