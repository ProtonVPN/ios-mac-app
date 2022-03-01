//
//  Created on 01/03/2022.
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
import AppKit

protocol TickboxViewDelegate: class {
    func toggleTickbox(_ tickboxView: SettingsTickboxView, to value: ButtonState)
}

class SettingsTickboxView: NSView, SwitchButtonDelegate {

    struct ViewModel {
        let labelText: String
        let buttonState: Bool
        let buttonEnabled: Bool
        let toolTip: String?

        init(labelText: String, buttonState: Bool, buttonEnabled: Bool = true, toolTip: String? = nil) {
            self.labelText = labelText
            self.buttonState = buttonState
            self.buttonEnabled = buttonEnabled
            self.toolTip = toolTip
        }
    }

    private weak var delegate: TickboxViewDelegate?

    @IBOutlet private weak var label: PVPNTextField!
    @IBOutlet private weak var switchButton: SwitchButton!
    @IBOutlet private weak var separator: NSBox!
    @IBOutlet private weak var infoIcon: NSImageView!

    private var model: ViewModel?

    static let infoIcon = NSImage(named: NSImage.Name("info_green"))

    var isOn: Bool {
        switchButton.currentButtonState == .on
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .checkBox
    }

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityValue() -> Any? {
        switchButton.currentButtonState == .on
    }

    override func accessibilityHelp() -> String? {
        model?.toolTip
    }

    override func accessibilityPerformPress() -> Bool {
        if let button = switchButton.buttonView {
            switchButton.buttonClicked(button)
        }
        return true
    }

    func setupItem(model: ViewModel, delegate: TickboxViewDelegate?) {
        setAccessibilityLabel(model.labelText)
        self.delegate = delegate
        self.model = model

        label.attributedStringValue = model.labelText.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        switchButton.setState(model.buttonState ? .on : .off)
        switchButton.delegate = self
        if !model.buttonEnabled {
            switchButton.enabled = false
        }
        infoIcon.image = model.toolTip != nil ? SettingsTickboxView.infoIcon : nil
        infoIcon.toolTip = model.toolTip
        separator.fillColor = .protonLightGrey()
    }

    func switchButtonClicked(_ button: NSButton) {
        delegate?.toggleTickbox(self, to: isOn ? .on : .off)
    }
}
