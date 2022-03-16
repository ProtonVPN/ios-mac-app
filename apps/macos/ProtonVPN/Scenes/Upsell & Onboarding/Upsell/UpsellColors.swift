//
//  Created on 21/02/2022.
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

import AppKit
import Modals
import Modals_macOS

struct UpsellColors: ModalsColors {
    public let background: NSColor
    public let text: NSColor
    public let brand: NSColor
    public let hoverBrand: NSColor
    public let weakText: NSColor

    public init() {
        background = .color(.background)
        text = .color(.text, .normal)
        brand = .color(.icon, .interactive)
        hoverBrand = .color(.icon, [.interactive, .hovered])
        weakText = .color(.text, .weak)
    }
}
