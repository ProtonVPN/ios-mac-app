//
//  TroubleshootingSwitchCell.swift
//  ProtonVPN - Created on 2020-04-27.
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

final class TroubleshootingSwitchCell: TroubleshootingCell {
    // MARK: - Static Properties

    static var switchCellId: String { String(describing: self) }

    // Views
    private lazy var toggleSwitch: UISwitch = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
    }

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSwitchView()
        setupSwitchConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupSwitchView() {
        contentView.addSubview(toggleSwitch)
    }

    private func setupSwitchConstraints() {
        NSLayoutConstraint.activate([
            // Toggle switch constraints
            toggleSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            toggleSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toggleSwitch.leadingAnchor.constraint(equalTo: descriptionLabel.trailingAnchor, constant: 8),

            // Update description label trailing constraint to accommodate switch
            descriptionLabel.trailingAnchor.constraint(equalTo: toggleSwitch.leadingAnchor, constant: -8),
        ])
    }

    // MARK: - Public Properties

    var isOn: Bool {
        get {
            toggleSwitch.isOn
        }
        set {
            toggleSwitch.isOn = newValue
        }
    }

    var isOnChanged: ((Bool) -> Void)?

    // MARK: - Actions

    @objc
    private func switchChanged() {
        isOnChanged?(toggleSwitch.isOn)
    }
}
