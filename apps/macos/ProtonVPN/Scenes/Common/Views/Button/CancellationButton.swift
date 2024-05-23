//
//  CancellationButton.swift
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

class CancellationButton: HoverDetectionButton {
    enum Style {
        case `default`
        case destructive
    }

    public var style: Style = .default

    private var isDestructive: Bool {
        return style == .destructive
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

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func viewWillDraw() {
        super.viewWillDraw()

        wantsLayer = true
        layer?.borderWidth = 2
        layer?.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        DarkAppearance {
            layer?.borderColor = self.cgColor(.border)
            layer?.backgroundColor = self.cgColor(.background)
        }
        configureTitle()
    }

    private func configureTitle() {
        attributedTitle = self.style(title, font: .themeFont(fontSize))
    }
}

extension CancellationButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .text:
            return .normal
        case .border:
            return !isDestructive || !isHovered ? .normal : [.danger, .hovered]
        case .background:
            if isDestructive {
                return isHovered ? [.danger, .hovered] : .transparent
            } else {
                return .transparent + (isHovered ? .hovered : [])
            }
        default:
            break
        }

        log.assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
