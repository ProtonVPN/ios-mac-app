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

final class PlaceholderView: UIView {

    // MARK: Outlets

    @IBOutlet private weak var itemsStackView: UIStackView!
    @IBOutlet private var contentView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!

    // MARK: Properties

    var onlyCountries: Bool = false {
        didSet {
            itemViews.forEach {
                if onlyCountries {
                    $0.isHidden = $0.item != PlaceholderItem.countries
                } else {
                    $0.isHidden = false
                }
            }
        }
    }

    private var itemViews: [PlaceholderItemView] = []

    // MARK: Setup

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        contentView = loadFromNib(name: "PlaceholderView")

        setupUI()
    }

    private func setupUI() {
        baseViewStyle(contentView)
        titleStyle(titleLabel)

        titleLabel.text = Localizable.searchSubtitle

        let items = [PlaceholderItem.countries, PlaceholderItem.cities, PlaceholderItem.servers].map { item -> UIView in
            let view = Bundle.module.loadNibNamed("PlaceholderItemView", owner: self, options: nil)?.first as! PlaceholderItemView
            view.item = item
            itemViews.append(view)
            return view
        }

        items.forEach {
            itemsStackView.addArrangedSubview($0)
        }
    }
}
