//
//  Created on 07/03/2023.
//
//  Copyright (c) 2023 Proton AG
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

import UIKit
import LegacyCommon
import NetShield

class NetShieldStatsItemView: UIView {
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadNib()
    }

    func loadNib() {
        Bundle.main.loadNibNamed("NetShieldStatsItemView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = bounds
        contentView.backgroundColor = .clear

        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        backgroundColor = .secondaryBackgroundColor()

        valueLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.font = UIFont.systemFont(ofSize: 13)
    }

    func setup(with model: NetShieldModel.Stat) {
        valueLabel.text = model.value
        titleLabel.text = model.title.replacingOccurrences(of: " ", with: "\n")

        valueLabel.textColor = model.isEnabled ? .normalTextColor() : .iconHint()
        titleLabel.textColor = model.isEnabled ? .weakTextColor() : .iconHint()
    }
}
