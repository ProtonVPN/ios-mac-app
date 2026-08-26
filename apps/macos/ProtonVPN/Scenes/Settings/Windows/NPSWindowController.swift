//
//  Created on 2026-09-01 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
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
import ComposableArchitecture
import ModalsShared
import SwiftUI

final class NPSWindowController: WindowController {
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    let store: StoreOf<NPSModalFeature>

    required init(store: StoreOf<NPSModalFeature>) {
        self.store = store
        let viewController = NSHostingController(rootView: NPSModalView(store: store))
        viewController.title = "Proton VPN"
        viewController.preferredContentSize = .init(width: 700, height: 600)

        let window = NSWindow(contentViewController: viewController)
        super.init(window: window)
    }

    override func windowShouldClose(_: NSWindow) -> Bool {
        store.send(.delegate(.dismissed))
        return true
    }
}
