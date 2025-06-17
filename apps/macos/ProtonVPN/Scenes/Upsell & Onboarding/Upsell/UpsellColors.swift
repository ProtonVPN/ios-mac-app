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
import Modals_macOS

struct UpsellColors: ModalsColors {
    public let background: NSColor
    public let text: NSColor
    public let brand: NSColor
    public let hoverBrand: NSColor
    public let weakText: NSColor
    public let linkNorm: NSColor
    public let textHint: NSColor
    public let backgroundHover: NSColor
    public let backgroundWeak: NSColor
    public let success: NSColor

    public init() {
        self.background = .color(.background)
        self.text = .color(.text, .normal)
        self.brand = .color(.icon, .interactive)
        self.hoverBrand = .color(.icon, [.interactive, .hovered])
        self.weakText = .color(.text, .weak)
        self.linkNorm = .color(.text, [.interactive, .hint])
        self.textHint = .color(.text, .hint)
        self.backgroundHover = .color(.background, [.transparent, .hovered])
        self.backgroundWeak = .color(.background, .weak)
        self.success = .color(.icon, .success)
    }
}
