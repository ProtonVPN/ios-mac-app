//
//  Created on 03/03/2023.
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

class NetShieldStatsTableViewCell: UITableViewCell {
    @IBOutlet private var adsStatView: NetShieldStatsItemView!
    @IBOutlet private var trackersStatView: NetShieldStatsItemView!
    @IBOutlet private var dataStatView: NetShieldStatsItemView!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupViews()
    }

    func setupViews() {
        selectionStyle = .none
        backgroundColor = .secondaryBackgroundColor()
    }

    func setup(with viewModel: NetShieldModel) {
        adsStatView.setup(with: viewModel.ads)
        trackersStatView.setup(with: viewModel.trackers)
        dataStatView.setup(with: viewModel.data)
    }
}
