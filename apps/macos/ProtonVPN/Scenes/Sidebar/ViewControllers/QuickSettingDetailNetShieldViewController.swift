//
//  Created on 23/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Cocoa
import NetShield
import SwiftUI

final class QuickSettingDetailNetShieldViewController: QuickSettingDetailViewController {
    private var netShieldStatsContainer: NSView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    var netShieldStatsView = NSHostingView(rootView: NetShieldStatsView())

    override func viewDidLoad() {
        super.viewDidLoad()

        // NetShield stats container
        titleHeaderStackView.insertArrangedSubview(netShieldStatsContainer, at: 1)

        NSLayoutConstraint.activate([
            netShieldStatsContainer.heightAnchor.constraint(equalToConstant: 72),
        ])

        setupNetShieldStatsContainer()
    }

    private func setupNetShieldStatsContainer() {
        guard let netShieldPresenter = presenter as? NetshieldDropdownPresenter,
              netShieldPresenter.isNetShieldStatsEnabled else {
            netShieldStatsContainer.removeFromSuperview()
            return
        }
        netShieldStatsView.translatesAutoresizingMaskIntoConstraints = false
        netShieldStatsContainer.addSubview(netShieldStatsView)
        NSLayoutConstraint.activate([
            netShieldStatsContainer.topAnchor.constraint(equalTo: netShieldStatsView.topAnchor),
            netShieldStatsContainer.bottomAnchor.constraint(equalTo: netShieldStatsView.bottomAnchor),
            netShieldStatsContainer.leadingAnchor.constraint(equalTo: netShieldStatsView.leadingAnchor),
            netShieldStatsContainer.trailingAnchor.constraint(equalTo: netShieldStatsView.trailingAnchor),
        ])
    }

    override func updateNetshieldStats() {
        if let model = (presenter as? NetshieldDropdownPresenter)?.netShieldViewModel {
            netShieldStatsView.rootView.viewModel = model
        }
    }
}
