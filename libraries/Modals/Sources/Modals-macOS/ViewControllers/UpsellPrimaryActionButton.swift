//
//  Created on 16/02/2022.
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

import Cocoa
import Theme

final class UpsellPrimaryActionButton: HoverDetectionButton {

    override var title: String {
        didSet {
            configureTitle()
        }
    }

    var fontSize: Double = 16 {
        didSet {
            configureTitle()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureButton()
    }

    override func viewWillDraw() {
        super.viewWillDraw()
        configureButton()
    }

    private func configureButton() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = isHovered ? .cgColor(.icon, [.interactive, .hovered]) : .cgColor(.icon, .interactive)
    }

    private func configureTitle() {
        attributedTitle = NSAttributedString(string: title,
                                             attributes: [.foregroundColor: NSColor.color(.text),
                                                .font: NSFont.systemFont(ofSize: fontSize)])
    }
}
