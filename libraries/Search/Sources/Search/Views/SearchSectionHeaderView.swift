//
//  Created on 07.03.2022.
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

final class SearchSectionHeaderView: UITableViewHeaderFooterView {
    public static var identifier: String {
        return String(describing: self)
    }

    public static var nib: UINib {
        return UINib(nibName: identifier, bundle: Bundle.module)
    }

    // MARK: Outlets

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var titleLabelLeadingConstraint: NSLayoutConstraint!

    // MARK: Properties

    var item: SearchResult? {
        didSet {
            titleLabel.text = item?.title
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let tableView = superview as? UITableView else {
            return
        }
        // The below is due to UITableViewHeaderFooterView not respecting the readableContentGuide. I couldn't find a bug report about this.
        titleLabelLeadingConstraint.constant = tableView.readableContentGuide.layoutFrame.minX
    }

    // MARK: Setup

    override func awakeFromNib() {
        super.awakeFromNib()

        baseViewStyle(self)
        baseViewStyle(contentView)
        cellHeaderStyle(titleLabel)
    }
}
