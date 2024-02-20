//
//  Created on 12/02/2024.
//
//  Copyright (c) 2024 Proton AG
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

enum KeyCode: UInt16, CaseIterable {
    case enter = 36
    case escape = 53

    static func isEventEligibleForDismiss(_ event: NSEvent) -> Bool {
        guard case .keyDown = event.type else {
            return false
        }
        return Self.allCases.map(\.rawValue).contains(event.keyCode)
    }
}

class OverlayViewController: NSViewController {

    var shouldDismissOnKeyDownEvent: Bool = true

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeKey()
        view.window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if shouldDismissOnKeyDownEvent, KeyCode.isEventEligibleForDismiss(event) {
            dismiss(self)
        } else {
            super.keyDown(with: event)
        }
    }

}
