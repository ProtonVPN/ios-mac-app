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
import Cocoa
import AppKit

class SettingsDropDownView: NSView {

    struct ViewModel {
        let labelText: String
        let toolTip: String?
        let progressIndicatorToolTip: String?
        let menuItems: [NSMenuItem]
        let selectedIndex: Int
    }

    private var model: ViewModel?

    @IBOutlet private weak var label: PVPNTextField!
    @IBOutlet private weak var separator: NSBox!
    @IBOutlet private weak var infoIcon: NSImageView!
    @IBOutlet private weak var popupButton: HoverDetectionPopUpButton!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!

    static let infoIcon = NSImage(named: NSImage.Name("info_green"))

    override func accessibilityRole() -> NSAccessibility.Role? {
        .popUpButton
    }

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityValue() -> Any? {
        popupButton.selectedItem?.title
    }

    override func accessibilityPerformPress() -> Bool {
        popupButton.accessibilityPerformPress()
    }

    override func accessibilityHelp() -> String? {
        model?.toolTip
    }

    func indexOfSelectedItem() -> Int {
        popupButton.indexOfSelectedItem
    }

    func startProgressIndicatorAnimation() {
        progressIndicator.startAnimation(nil)
    }

    func stopProgressIndicatorAnimation() {
        progressIndicator.stopAnimation(nil)
    }

    func setupItem(model: ViewModel, target: AnyObject, action: Selector) {
        self.model = model
        setAccessibilityLabel(model.labelText)

        label.attributedStringValue = model.labelText.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        infoIcon.image = model.toolTip != nil ? SettingsTickboxView.infoIcon : nil
        infoIcon.toolTip = model.toolTip
        separator.fillColor = .protonLightGrey()
        
        popupButton.isBordered = false
        popupButton.target = target
        popupButton.action = action

        popupButton.menu?.items = model.menuItems

        popupButton.selectItem(at: model.selectedIndex)

        if let indicator = progressIndicator {
            indicator.isDisplayedWhenStopped = false
            indicator.appearance = NSAppearance(named: .darkAqua)
            indicator.toolTip = model.progressIndicatorToolTip
        }
    }
}
