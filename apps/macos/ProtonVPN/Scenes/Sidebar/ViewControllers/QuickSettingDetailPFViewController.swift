//
//  Created on 31/07/2025 by Max Kupetskyi.
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
import NATPMPUI
import SwiftUI

final class QuickSettingDetailPFViewController: QuickSettingDetailViewController {
    var portView = NSHostingView(rootView: NATPMPPortView()).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.isHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Port forwarding view to the stack
        buttonsAndNoteView.insertArrangedSubview(portView, at: 1)
        portView.widthAnchor.constraint(equalTo: buttonsAndNoteView.widthAnchor).isActive = true

        setupPFContainer()
    }

    override func updatePortForwardingContainer() {
        setupPFContainer()
    }

    // MARK: - Private

    private func setupPFContainer() {
        guard let pfPresenter = presenter as? PortForwardingDropdownPresenter else {
            portView.isHidden = true
            return
        }
        portView.isHidden = !pfPresenter.portForwardingViewVisible
    }
}
