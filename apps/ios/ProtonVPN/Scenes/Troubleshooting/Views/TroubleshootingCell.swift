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
    // MARK: - Static Properties

    static var cellIdentifier: String { String(describing: self) }

    // Views
    var titleLabel: UILabel = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.numberOfLines = 0
        $0.lineBreakMode = .byTruncatingTail
        $0.textColor = .normalTextColor()
        $0.font = UIFont.boldSystemFont(ofSize: 17)
    }

    var descriptionLabel: UITextView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.isScrollEnabled = false // Enables auto-height
        $0.isUserInteractionEnabled = true
        $0.isEditable = false
        $0.isSelectable = true
        $0.textContainer.lineFragmentPadding = 0
//        $0.backgroundColor = backgroundColor
        $0.tintColor = .brandColor()
        $0.linkTextAttributes = [
            .foregroundColor: UIColor.brandColor(),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
    }

    // MARK: - Initialization

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

        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title label constraints
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 16),

            // Description label constraints
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            descriptionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
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
        }
    }
}

extension NSObject: With {}
