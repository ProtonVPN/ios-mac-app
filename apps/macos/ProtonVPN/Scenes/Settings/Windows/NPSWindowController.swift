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

import Announcement
import AppKit
import ComposableArchitecture
import SwiftUI

final class NPSWindowController: WindowController {
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    private static let windowSize = CGSize(width: 650, height: 550)

    let store: StoreOf<NPSModalFeature>

    required init(store: StoreOf<NPSModalFeature>) {
        self.store = store
        let view = NPSModalView(store: store)
            .padding(.vertical, .themeSpacing24)
            .frame(width: Self.windowSize.width, height: Self.windowSize.height) // gives the window its size
        let viewController = NSHostingController(rootView: view)
        viewController.title = "Proton VPN"

        let window = NSWindow(contentViewController: viewController)
        window.backgroundColor = .color(.background)
        super.init(window: window)
    }

    override func windowShouldClose(_: NSWindow) -> Bool {
        // This is being called when either the user tapped on close button or we dismissed the view from SwiftUI context.
        store.send(.delegate(.dismiss))
        return true
    }
}
