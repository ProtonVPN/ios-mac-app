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

import BugReportShared
import Cocoa
import Ergonomics
import Foundation
import SharedViews
import Theme

final class TroubleshootingRowItem: NSTableRowView {
    // MARK: Properties

    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.textColor = .color(.text)
        label.font = NSFont.boldSystemFont(ofSize: 17)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let switchView: SwitchButton = {
        let switchButton = SwitchButton()
        switchButton.translatesAutoresizingMaskIntoConstraints = false
        return switchButton
    }()

    private let textView: NSTextView = {
        let textView = NSTextView()
        textView.linkTextAttributes = [
            NSAttributedString.Key.foregroundColor: NSColor.color(.text, .link),
        ]
        textView.isEditable = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.backgroundColor = .clear
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    private var heightConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    var item: TroubleshootItem? {
        didSet {
            guard let item else {
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
            DarkAppearance {
                switchView.maskColor = .cgColor(.background)
            }
        }
    }

    // MARK: Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Setup

    private func setup() {
        addSubview(titleLabel)
        addSubview(switchView)
        addSubview(textView)

        NSLayoutConstraint.activate([
            // Title label constraints
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            // Switch button constraints
            switchView.centerYAnchor.constraint(equalTo: centerYAnchor),
            switchView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            switchView.widthAnchor.constraint(equalToConstant: 35),
            switchView.heightAnchor.constraint(equalToConstant: 20),

            // Text view constraints
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            textView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor, constant: -4),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
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
    func switchButtonClicked(_: NSButton) {
        (item as? ActionableTroubleshootItem)?.set(isOn: switchView.currentButtonState == .on)
    }
}
