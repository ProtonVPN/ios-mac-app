//
//  Created on 02.03.2022.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import UIKit
import Strings

final class NoResultsView: UIView {

    // MARK: Outlets

    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private var contentView: UIView!

    // MARK: Setup

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        contentView = loadFromNib(name: "NoResultsView")

        setupUI()
    }

    private func setupUI() {
        baseViewStyle(contentView)
        titleStyle(titleLabel)
        subtitleStyle(subtitleLabel)

        titleLabel.text = Localizable.searchNoResultsTitle
        subtitleLabel.text = Localizable.searchNoResultsSubtitle
    }
}
