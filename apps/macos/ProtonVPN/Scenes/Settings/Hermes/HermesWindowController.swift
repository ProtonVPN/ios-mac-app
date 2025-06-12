//
//  Created on 26/05/2025 by adam.
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

import AppKit
import Strings

final class HermesWindowController: WindowController {
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    init(viewModel: HermesViewModel) {
        let window = HermesWindow(viewModel: viewModel)
        super.init(window: window)
        setupWindow()
        monitorsKeyEvents = true
    }

    private func setupWindow() {
        guard let window else {
            return
        }

        window.styleMask.remove(.resizable)
        window.title = Localizable.preferences
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .color(.background)
    }
}
