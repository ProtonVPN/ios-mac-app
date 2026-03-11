//
//  Created on 09/03/2026 by Max Kupetskyi.
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

import Cocoa
import Ergonomics
import SharedViews
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

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureButton()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        super.updateLayer()
        configureButton()
    }

    private func configureButton() {
        layer?.cornerRadius = 8
        DarkAppearance {
            layer?.backgroundColor = isHovered ? .cgColor(.icon, [.interactive, .hovered]) : .cgColor(.icon, .interactive)
        }
    }

    private func configureTitle() {
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.color(.text),
                .font: NSFont.systemFont(ofSize: fontSize),
            ]
        )
    }
}
