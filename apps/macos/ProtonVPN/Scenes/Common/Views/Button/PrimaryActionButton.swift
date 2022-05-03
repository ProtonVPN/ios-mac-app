//
//  GreenAffirmationButton.swift
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
import vpncore

class PrimaryActionButton: HoverDetectionButton {
    var actionType = PrimaryActionType.confirmative {
        didSet {
            configureButton()
        }
    }
    
    override var title: String {
        didSet {
            configureTitle()
        }
    }
    
    var fontSize: AppTheme.FontSize = .heading4 {
        didSet {
            configureTitle()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureButton()
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        configureButton()
    }
    
    private func configureButton() {
        wantsLayer = true
        layer?.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        layer?.backgroundColor = self.cgColor(.background)
    }
    
    private func configureTitle() {
        attributedTitle = self.style(title, font: .themeFont(fontSize))
    }

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += 16
        return size
    }
}

extension PrimaryActionButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .text:
            return .normal
        case .border:
            let hover: AppTheme.Style = isHovered ? .hovered : []
            switch actionType {
            case .confirmative, .cancel:
                return .interactive + hover
            case .destructive:
                return .danger + hover
            case .secondary:
                return .normal
            }
        case .background:
            let hover: AppTheme.Style = isHovered ? .hovered : []
            switch actionType {
            case .confirmative, .cancel:
                return .interactive + hover
            case .destructive:
                return .danger + hover
            case .secondary:
                return .transparent + hover
            }
        default:
            break
        }

        assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
