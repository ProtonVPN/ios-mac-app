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
        textField.textColor = .color(.text)
        return textField
    }()

    private var size: NSSize?
    private let margin: CGFloat = 14

    init(message: String) {
        super.init(frame: .zero)
        setup()
        label.stringValue = message
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = .cgColor(.background, .interactive)

        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    func show(from parentView: NSView, duration: TimeInterval = 3) {
        let labelSize = label.sizeThatFits(NSSize(width: parentView.frame.width - 4 * margin, height: parentView.frame.height))
        size = NSSize(width: labelSize.width + 2 * margin, height: labelSize.height + 2 * margin)
        invalidateIntrinsicContentSize()
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: labelSize.width + 2 * margin),
            label.heightAnchor.constraint(equalToConstant: labelSize.height)
        ])

        parentView.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parentView.topAnchor, constant: 2 * margin),
            centerXAnchor.constraint(equalTo: parentView.centerXAnchor)
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.dismiss()
        }
    }

    func dismiss() {
        removeFromSuperview()
    }

    override var intrinsicContentSize: NSSize {
        return size ?? .zero
    }
}
