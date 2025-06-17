//
//  Created on 2025-04-07 by Pawel Jurczyk.
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
import ComposableArchitecture
import SwiftUI
import Theme

public extension NSViewController {
    static func plutonium(store: StoreOf<PlutoniumFeature>) -> NSViewController {
        let view = PlutoniumView(store: store)
            .frame(Theme.Constants.settingsViewSize)

        let controller = NSHostingController(rootView: view)
        controller.preferredContentSize = Theme.Constants.settingsViewSize
        controller.sizingOptions = .preferredContentSize
        return controller
    }
}
