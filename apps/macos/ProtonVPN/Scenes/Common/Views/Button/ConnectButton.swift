//
//  ConnectButton.swift
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
import LegacyCommon
import Theme
import Ergonomics
import Strings

class ConnectButton: ResizingTextButton {
    
    override var title: String {
        didSet {
            needsDisplay = true
        }
    }
    
    var isConnected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    var upgradeRequired: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    var nameForAccessibility: String? {
        didSet {
            needsDisplay = true
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureButton()
        setAccessibilityRole(.button)
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        configureButton()
    }

    override var intrinsicContentSize: NSSize {
        if upgradeRequired {
            // No text is displayed, so set the size to the size of the image (Theme.Asset.vpnSubscriptionBadge.image)
            return NSSize(width: 38.75, height: 24)
        }
        // If displaying text, `ResizingTextButton` calculates size based on the width of `attributedString`
        return super.intrinsicContentSize
    }

    private func setup(withText text: String) {
        layer?.borderWidth = 2
        DarkAppearance {
            layer?.backgroundColor = self.cgColor(.background)
            layer?.borderColor = self.cgColor(.border)
        }
        self.image = nil
        attributedTitle = text.styled(font: .themeFont(.small))
    }

    private func setup(withImage image: NSImage) {
        layer?.borderColor = .clear
        layer?.backgroundColor = .clear
        self.image = image
    }

    private func configureButton() {
        wantsLayer = true
        layer?.cornerRadius = AppTheme.ButtonConstants.cornerRadius

        if isConnected {
            let title = isHovered ? Localizable.disconnect : Localizable.connected
            setup(withText: title)
            setAccessibilityLabel(String(format: "%@ %@", Localizable.disconnect, nameForAccessibility ?? ""))
        } else if upgradeRequired {
            setup(withImage: Theme.Asset.vpnSubscriptionBadge.image)
            setAccessibilityLabel(String(format: "%@ %@", Localizable.upgradeRequired, nameForAccessibility ?? ""))
        } else { // disconnected, upgrade not required
            setup(withText: Localizable.connect)
            setAccessibilityLabel(String(format: "%@ %@", Localizable.connect, nameForAccessibility ?? ""))
        }
    }
}

extension ConnectButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        if context == .text {
            return .normal
        }

        let defaultStyle: AppTheme.Style = context == .border ? .normal : .weak
        if isConnected {
            return isHovered ? .danger : defaultStyle
        } else {
            return isHovered ? .interactive : defaultStyle
        }
    }
}
