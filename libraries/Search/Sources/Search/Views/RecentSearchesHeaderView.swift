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

protocol RecentSearchesHeaderViewDelegate: AnyObject {
    func userDidRequestClear()
}

final class RecentSearchesHeaderView: UIView {

    // MARK: Outlets

    @IBOutlet private weak var clearButton: UIButton!
    @IBOutlet private weak var titleLabel: UILabel!

    // MARK: Properties

    weak var delegate: RecentSearchesHeaderViewDelegate?

    var count: Int = 0 {
        didSet {
            titleLabel.text = "\(Localizable.searchRecentHeader) (\(count))"
        }
    }

    // MARK: Setup

    override func awakeFromNib() {
        super.awakeFromNib()

        baseViewStyle(self)
        subtitleStyle(titleLabel)
        textButtonStyle(clearButton)

        clearButton.setTitle(Localizable.searchRecentClear, for: .normal)
        clearButton.addTarget(self, action: #selector(clearPressed), for: .touchUpInside)
    }

    // MARK: Actions

    @objc private func clearPressed() {
        delegate?.userDidRequestClear()
    }
}
