//
//  TroubleshootingRowItem.swift
//  ProtonVPN - Created on 26.02.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation
import Cocoa
import vpncore

final class TroubleshootingRowItem: NSTableRowView {

    // MARK: Outlets

    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var switchView: SwitchButton!
    private let textView = NSTextView()

    // MARK: Properties

    private var heightConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    var item: TroubleshootItem? {
        didSet {
            guard let item = item else {
                return
            }

            titleLabel.stringValue = item.title
            let length = item.description.string.count
            let value = NSMutableAttributedString(attributedString: item.description)
            value.addAttribute(NSAttributedString.Key.font, value: NSFont.themeFont(.small), range: NSRange(location: 0, length: length))
            value.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor.color(.text), range: NSRange(location: 0, length: length))
            textView.textStorage?.setAttributedString(value)

            guard let actionable = item as? ActionableTroubleshootItem else {
                switchView.isHidden = true
                trailingConstraint?.constant = 8
                return
            }

            trailingConstraint?.constant = -80
            switchView.isHidden = false
            switchView.setState(actionable.isOn ? .on : .off)
        }
    }
    
    override  func awakeFromNib() {
        super.awakeFromNib()

        setup()
    }

    // MARK: Setup

    private func setup() {
        titleLabel.textColor = .color(.text)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 17)

        textView.linkTextAttributes = [
            NSAttributedString.Key.foregroundColor: NSColor.color(.text, .interactive)
        ]

        textView.isEditable = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.backgroundColor = .clear
        addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            textView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor, constant: -4),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        trailingConstraint = textView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8)
        trailingConstraint?.isActive = true
        heightConstraint = textView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint?.isActive = true

        switchView.delegate = self
    }

    override func layout() {
        super.layout()

        guard let container = textView.textContainer, let manager = container.layoutManager else {
            return
        }
        manager.ensureLayout(for: container)
        heightConstraint?.constant = manager.usedRect(for: container).size.height
    }
}

// MARK: Switch button delegate

extension TroubleshootingRowItem: SwitchButtonDelegate {
    func switchButtonClicked(_ button: NSButton) {
        (item as? ActionableTroubleshootItem)?.set(isOn: switchView.currentButtonState == .on)
    }
}
