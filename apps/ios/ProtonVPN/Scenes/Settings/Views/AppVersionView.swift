//
//  AppVersionView.swift
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

import Ergonomics
import UIKit

final class AppVersionView: UIView {
    // MARK: - UI Elements

    private let appVersionLabel: UILabel = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.textAlignment = .center
        $0.numberOfLines = 0
        $0.lineBreakMode = .byTruncatingTail
        $0.font = UIFont.systemFont(ofSize: 15)
        $0.textColor = .weakTextColor()
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupView() {
        backgroundColor = .backgroundColor()

        addSubview(appVersionLabel)
        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            appVersionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            appVersionLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            appVersionLabel.topAnchor.constraint(equalTo: topAnchor, constant: Dimensions.topInset),
            appVersionLabel.heightAnchor.constraint(equalToConstant: Dimensions.height),
        ])
    }

    // MARK: - Public Interface

    func setVersionText(_ text: String) {
        appVersionLabel.text = text
    }
}

extension AppVersionView {
    private enum Dimensions {
        static let topInset: CGFloat = 20
        static let height: CGFloat = 20
    }
}
