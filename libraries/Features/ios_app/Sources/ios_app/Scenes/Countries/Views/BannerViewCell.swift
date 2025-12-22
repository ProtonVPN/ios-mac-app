//
//  BannerViewCell.swift
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

class BannerViewCell: UITableViewCell {
    private let roundedBackgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondaryBackgroundColor()
        view.layer.cornerRadius = Dimensions.RoundedBackgroundView.cornerRadius
        return view
    }()

    private let leftImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .normalTextColor()
        label.font = .systemFont(ofSize: Dimensions.labelFontSize)
        label.numberOfLines = 0
        return label
    }()

    private let rightChevron: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.tintColor = .iconHint()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = Dimensions.StackView.spacing
        stackView.alignment = .center
        return stackView
    }()

    var viewModel: BannerViewModel? {
        didSet {
            guard let viewModel else { return }
            leftImageView.image = viewModel.leftIcon.image
            label.text = viewModel.text
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .backgroundColor()
        selectionStyle = .none

        contentView.addSubview(roundedBackgroundView)
        roundedBackgroundView.addSubview(stackView)

        [leftImageView, label, rightChevron].forEach(stackView.addArrangedSubview)

        NSLayoutConstraint.activate(
            [
                // Rounded background view constraints
                roundedBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Dimensions.RoundedBackgroundView.verticalMargin),
                roundedBackgroundView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
                roundedBackgroundView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
                roundedBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Dimensions.RoundedBackgroundView.verticalMargin),

                // Stack view constraints
                stackView.topAnchor
                    .constraint(equalTo: roundedBackgroundView.topAnchor, constant: Dimensions.StackView.verticalPadding),
                stackView.leadingAnchor
                    .constraint(
                        equalTo: roundedBackgroundView.leadingAnchor,
                        constant: Dimensions.StackView.horizontalPadding
                    ),
                stackView.trailingAnchor.constraint(equalTo: roundedBackgroundView.trailingAnchor, constant: -Dimensions.StackView.horizontalPadding),
                stackView.bottomAnchor.constraint(equalTo: roundedBackgroundView.bottomAnchor, constant: -Dimensions.StackView.verticalPadding),

                // Left image view size
                leftImageView.widthAnchor.constraint(equalToConstant: Dimensions.iconSize),
                leftImageView.heightAnchor.constraint(equalToConstant: Dimensions.iconSize),

                // Right chevron size
                rightChevron.widthAnchor.constraint(equalToConstant: Dimensions.iconSize),
                rightChevron.heightAnchor.constraint(equalToConstant: Dimensions.iconSize),
            ]
        )

        // Set content hugging and compression resistance priorities
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        leftImageView.setContentHuggingPriority(.required, for: .horizontal)
        rightChevron.setContentHuggingPriority(.required, for: .horizontal)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        selectionStyle = .none
    }
}

extension BannerViewCell {
    private enum Dimensions {
        enum RoundedBackgroundView {
            static let cornerRadius: CGFloat = 12
            static let verticalMargin: CGFloat = 8
        }

        enum StackView {
            static let horizontalPadding: CGFloat = 12
            static let verticalPadding: CGFloat = 12
            static let spacing: CGFloat = 12
        }

        static let iconSize: CGFloat = 24
        static let labelFontSize: CGFloat = 13
    }
}
