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

import Foundation
import UIKit

class NetShieldStatsTableViewCell: UITableViewCell {
    @IBOutlet private var adsStatView: NetShieldStatsItemView!
    @IBOutlet private var trackersStatView: NetShieldStatsItemView!
    @IBOutlet private var dataStatView: NetShieldStatsItemView!

    var viewModel: NetShieldStatsViewModel = .disabled {
        didSet {
            setup(with: viewModel)
        }
    }

    private var statViews: [NetShieldStatsItemView] { [adsStatView, trackersStatView, dataStatView] }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        selectionStyle = .none
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupViews()
    }

    func setupViews() {
        backgroundColor = .secondaryBackgroundColor()
    }

    func setup(with viewModel: NetShieldStatsViewModel) {
        adsStatView.setup(with: viewModel.adsModel)
        trackersStatView.setup(with: viewModel.trackersModel)
        dataStatView.setup(with: viewModel.dataModel)
    }

}

enum NetShieldStatsViewModel {
    case disabled
    case enabled(adsBlocked: Int, trackersStopped: Int, dataSaved: Int64, paused: Bool)

    var adsModel: NetShieldStatsItemModel {
        let title: String = "Ads\nblocked"

        guard case .enabled(let adsBlocked, _, _, let paused) = self else {
            return .disabled(title: title)
        }

        return .init(title: title, value: "\(adsBlocked)", isEnabled: !paused)
    }

    var trackersModel: NetShieldStatsItemModel {
        let title: String = "Trackers\nstopped"

        guard case .enabled(_, let trackersStopped, _, let paused) = self else {
            return .disabled(title: title)
        }

        return .init(title: title, value: "\(trackersStopped)", isEnabled: !paused)
    }

    var dataModel: NetShieldStatsItemModel {
        let title: String = "Data\nsaved"

        guard case .enabled(_, _, let dataSaved, let paused) = self else {
            return .disabled(title: title)
        }

        let value = ByteCountFormatter().string(fromByteCount: dataSaved)

        return .init(title: title, value: value, isEnabled: !paused)
    }

}
