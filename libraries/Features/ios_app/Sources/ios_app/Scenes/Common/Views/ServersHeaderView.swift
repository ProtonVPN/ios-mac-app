//
//  ServersHeaderView.swift
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

import ProtonCoreUIFoundations
import UIKit

class ServersHeaderView: UITableViewHeaderFooterView {
    private let colorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .backgroundColor()
        view.preservesSuperviewLayoutMargins = true
        return view
    }()

    private let serversName: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .weakTextColor()
        label.font = .systemFont(ofSize: Dimensions.labelFontSize)
        return label
    }()

    private let infoBtn: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(IconProvider.infoCircle, for: .normal)
        button.tintColor = .iconNorm()
        button.isHidden = true
        return button
    }()

    var callback: (() -> Void)? {
        didSet {
            infoBtn.isHidden = callback == nil
        }
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        contentView.addSubview(colorView)
        colorView.addSubview(serversName)
        colorView.addSubview(infoBtn)

        infoBtn.addTarget(self, action: #selector(didTapInfoBtn), for: .touchUpInside)

        let trailingConstraint = serversName.trailingAnchor.constraint(equalTo: colorView.layoutMarginsGuide.trailingAnchor)
        trailingConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            // Color view fills entire content view
            colorView.topAnchor.constraint(equalTo: contentView.topAnchor),
            colorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            colorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            colorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Server name label with margins
            serversName.leadingAnchor.constraint(equalTo: colorView.layoutMarginsGuide.leadingAnchor),
            trailingConstraint,
            serversName.bottomAnchor.constraint(equalTo: colorView.bottomAnchor, constant: -Dimensions.verticalPadding),

            // Info button positioned at trailing edge
            infoBtn.trailingAnchor.constraint(equalTo: colorView.layoutMarginsGuide.trailingAnchor),
            infoBtn.bottomAnchor.constraint(equalTo: colorView.bottomAnchor, constant: -Dimensions.verticalPadding),
            infoBtn.widthAnchor.constraint(equalToConstant: Dimensions.buttonSize),
            infoBtn.heightAnchor.constraint(equalToConstant: Dimensions.buttonSize),
        ])
    }

    func setName(name: String?) {
        guard let name else {
            serversName.isHidden = true
            return
        }

        serversName.isHidden = false
        serversName.text = name
    }

    func setColor(color: UIColor) {
        colorView.backgroundColor = color
    }

    @objc
    private func didTapInfoBtn(_: Any) {
        callback?()
    }
}

extension ServersHeaderView {
    private enum Dimensions {
        static let labelFontSize: CGFloat = 15
        static let verticalPadding: CGFloat = 8
        static let buttonSize: CGFloat = 24
    }
}
