//
//  TextFieldWithFocus.swift
//  ProtonVPN - Created on 27.06.19.
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

import Cocoa

class TextFieldWithFocus: NSTextField {
    weak var focusDelegate: TextFieldFocusDelegate?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTransparency()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTransparency()
    }

    override func mouseDown(with event: NSEvent) {
        focusDelegate?.willReceiveFocus(self)
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        if let focusDelegate = focusDelegate {
            guard focusDelegate.shouldBecomeFirstResponder else {
                return false
            }

            focusDelegate.willReceiveFocus(self)
        }
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        defer {
            focusDelegate?.didLoseFocus(self)
        }
        return super.resignFirstResponder()
    }

    // swiftlint:disable cyclomatic_complexity
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == NSEvent.EventType.keyDown else {
            return super.performKeyEquivalent(with: event)
        }

        var selector: Selector?
        switch event.modifierFlags.deviceIndependentFlags {
        case .command:
            switch event.charactersIgnoringModifiers! {
            case "x":
                selector = #selector(NSText.cut(_:))
            case "c":
                selector = #selector(NSText.copy(_:))
            case "v":
                selector = #selector(NSText.paste(_:))
            case "z":
                selector = Selector(("undo:"))
            case "a":
                selector = #selector(NSResponder.selectAll(_:))
            default:
                break
            }
        case .command.plus(.shift) where event.charactersIgnoringModifiers == "Z":
            selector = Selector(("redo:"))
        default:
            break
        }

        if let selector, NSApp.sendAction(selector, to: nil, from: self) {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    // swiftlint:enable cyclomatic_complexity

    // MARK: - Private functions

    private func setupTransparency() {
        isBordered = false
        focusRingType = .none
        drawsBackground = false
    }
}

private extension NSEvent.ModifierFlags {
    var deviceIndependentFlags: Self {
        Self(rawValue: rawValue & Self.deviceIndependentFlagsMask.rawValue)
    }

    func plus(_ another: Self) -> Self {
        Self(rawValue: self.rawValue | another.rawValue)
    }
}
