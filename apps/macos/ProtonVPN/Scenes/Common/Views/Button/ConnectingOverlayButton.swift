//
//  CancelConnectingButton.swift
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

class ConnectingOverlayButton: HoverDetectionButton {
    enum Style {
        case normal
        case interactive
    }
    
    public var style: Style = .normal {
        didSet {
            needsDisplay = true
        }
    }
    
    override var title: String {
        didSet {
            needsDisplay = true
        }
    }
    
    // It differs from the one in HoverDetectionButton because this button is used in child window.
    override func trackingOptions() -> NSTrackingArea.Options {
        return [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp]
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        updateTrackingAreas()
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        wantsLayer = true
        layer?.borderWidth = 2
        layer?.cornerRadius = AppTheme.ButtonConstants.cornerRadius

        DarkAppearance {
            layer?.backgroundColor = self.cgColor(.background)
            layer?.borderColor = self.cgColor(.border)
        }
        attributedTitle = self.style(title, font: .themeFont(.heading4))
    }
}

extension ConnectingOverlayButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        let hover: AppTheme.Style = isHovered ? .hovered : []
        switch context {
        case .background:
            switch style {
            case .interactive:
                return .interactive + hover
            case .normal:
                return .transparent + hover
            }
        case .border:
            switch style {
            case .interactive:
                return .interactive + hover
            case .normal:
                return .normal
            }
        case .text:
            return .normal
        default:
            break
        }
        log.assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
