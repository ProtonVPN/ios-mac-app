//
//  TroubleshootingCell.swift
//  ProtonVPN - Created on 2020-04-24.
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

import Ergonomics
import UIKit

class TroubleshootingCell: UITableViewCell {
    static var cellIdentifier: String { String(describing: self) }

    private var titleLabel: UILabel = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.numberOfLines = 0
        $0.lineBreakMode = .byTruncatingTail
        $0.textColor = .normalTextColor()
        $0.font = UIFont.boldSystemFont(ofSize: 17)
    }

    private var descriptionLabel: UITextView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.isScrollEnabled = false // Enables auto-height
        $0.isUserInteractionEnabled = true
        $0.isEditable = false
        $0.isSelectable = true
        $0.textContainer.lineFragmentPadding = 0
        $0.textContainerInset = .zero
        $0.tintColor = .brandColor()
        $0.linkTextAttributes = [
            .foregroundColor: UIColor.brandColor(),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        $0.backgroundColor = .clear
    }

    private var textsStackView: UIStackView = .init().with {
        $0.axis = .vertical
        $0.alignment = .leading
        $0.spacing = 8
        $0.distribution = .fill
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        $0.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }

    var mainStackView: UIStackView = .init().with {
        $0.axis = .horizontal
        $0.alignment = .center
        $0.spacing = 16
        $0.distribution = .fill
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        // Configure cell properties
        backgroundColor = .backgroundColor()
        selectionStyle = .none

        [titleLabel, descriptionLabel].forEach(textsStackView.addArrangedSubview)
        [textsStackView].forEach(mainStackView.addArrangedSubview)
        contentView.addSubview(mainStackView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        selectionStyle = .none
    }

    // MARK: - Public setters

    var title: String? {
        get {
            titleLabel.text
        }
        set {
            titleLabel.text = newValue
        }
    }

    var descriptionAttributed: NSAttributedString {
        get {
            descriptionLabel.attributedText
        }
        set {
            let string = NSMutableAttributedString(attributedString: newValue)
            string.addTextAttributes(withColor: .weakTextColor(), font: UIFont.systemFont(ofSize: 17), alignment: .left)
            descriptionLabel.attributedText = string
            descriptionLabel.sizeToFit()

            // Force layout update to ensure proper text rendering
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
}

extension NSObject: With {}
