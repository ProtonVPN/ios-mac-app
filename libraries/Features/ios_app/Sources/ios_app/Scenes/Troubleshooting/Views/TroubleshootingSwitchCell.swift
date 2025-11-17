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
    static var switchCellId: String { String(describing: self) }

    private lazy var toggleSwitch: UISwitch = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        $0.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        $0.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSwitchView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupSwitchView() {
        mainStackView.addArrangedSubview(toggleSwitch)
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

        // Force layout update to ensure proper rendering
        setNeedsLayout()
        layoutIfNeeded()
    }
}
