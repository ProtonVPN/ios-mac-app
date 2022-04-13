//
//  Created on 13.04.2022.
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

import Foundation
import Cocoa

final class BannerView: NSView {
    private lazy var label: NSTextField = {
        let textField = NSTextField()
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.usesSingleLineMode = false
        textField.cell?.wraps = true
        textField.cell?.isScrollable = false
        textField.font = NSFont.systemFont(ofSize: 15)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.alignment = .center
        textField.textColor = NSColor.protonWhite()
        return textField
    }()

    private var size: NSSize?
    private let margin: CGFloat = 14

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.protonGreen().cgColor

        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    func show(message: String, parentView: NSView) {
        label.stringValue = message
        let labelSize = label.sizeThatFits(NSSize(width: parentView.frame.width - 4 * margin, height: parentView.frame.height))
        size = NSSize(width: labelSize.width + 2 * margin, height: labelSize.height + 2 * margin)
        invalidateIntrinsicContentSize()
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: labelSize.width + 4 * margin),
            label.heightAnchor.constraint(equalToConstant: labelSize.height)
        ])

        parentView.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parentView.topAnchor, constant: 2 * margin),
            centerXAnchor.constraint(equalTo: parentView.centerXAnchor)
        ])
    }

    override var intrinsicContentSize: NSSize {
        return size ?? .zero
    }
}
