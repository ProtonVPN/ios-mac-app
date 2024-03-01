//
//  StatusBarAppConnectButton.swift
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

class LargeDropdownButton: HoverDetectionButton {
    
    var isConnected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    var dropDownExpanded: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        configureButton()
    }
    
    private func configureButton() {
        wantsLayer = true
        isBordered = false
        title = ""
    }
}

// swiftlint:disable operator_usage_whitespace
class StatusBarAppConnectButton: LargeDropdownButton {
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let lw: CGFloat = 2
        let ib: CGRect
        context.setStrokeColor(self.cgColor(.border))
        context.setFillColor(self.cgColor(.background))

        if isConnected {
            ib = NSRect(x: bounds.origin.x + lw/2, y: bounds.origin.y + lw/2, width: bounds.width - lw, height: bounds.height - lw)
        } else {
            ib = NSRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width - lw/2, height: bounds.height)
        }
        
        context.setLineWidth(lw)
        
        let path = CGMutablePath()
        path.addRoundedRectangle(ib, cornerRadius: AppTheme.ButtonConstants.cornerRadius)
        
        context.addPath(path)
        context.drawPath(using: .fillStroke)

        let buttonTitle = self.style(isConnected ? Localizable.disconnect : Localizable.quickConnect, font: .themeFont(.heading4))
        let textHeight = buttonTitle.size().height
        buttonTitle.draw(in: CGRect(
            x: 0,
            y: (bounds.height - textHeight) / 2,
            width: bounds.width,
            height: textHeight
        ))
    }
}
// swiftlint:enable operator_usage_whitespace

extension StatusBarAppConnectButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        if isConnected {
            switch context {
            case .text:
                return .normal
            case .border:
                return isHovered ? .danger : .normal
            case .background:
                return isHovered ? .danger : .transparent
            default:
                break
            }
        } else {
            switch context {
            case .text:
                return .normal
            case .border:
                return .transparent
            case .background:
                return .interactive + (isHovered ? .hovered : [])
            default:
                break
            }
        }
        log.assertionFailure("Context not handled: \(context)")
        return .normal
    }
}

// swiftlint:disable operator_usage_whitespace
class StatusBarAppProfileDropdownButton: LargeDropdownButton {
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let buttonMargin: CGFloat = 5

        let lw: CGFloat = 2
        let ib: CGRect
        context.setStrokeColor(self.cgColor(.border))
        context.setFillColor(self.cgColor(.background))
        if isConnected {
            ib = NSRect(x: bounds.origin.x - lw/2 + buttonMargin, y: bounds.origin.y + lw/2, width: bounds.width - lw/2 - buttonMargin, height: bounds.height - lw)
        } else {
            ib = NSRect(x: bounds.origin.x + lw/2 + buttonMargin, y: bounds.origin.y, width: bounds.width - lw/2 - buttonMargin, height: bounds.height)
        }
        
        context.setLineWidth(lw)

        let path = CGMutablePath()
        path.addRoundedRectangle(ib, cornerRadius: AppTheme.ButtonConstants.cornerRadius)

        let ah: CGFloat = dropDownExpanded ? -4 : 4 // arrowHeight
        let borderMargin: CGFloat = self.customStyle(context: .border) == .transparent ? 0 : 2
        let midX: CGFloat = bounds.midX - borderMargin + buttonMargin/2
        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: midX - ah, y: bounds.midY - ah/2))
        arrow.addLine(to: CGPoint(x: midX, y: bounds.midY + ah/2))
        arrow.addLine(to: CGPoint(x: midX + ah, y: bounds.midY - ah/2))
        
        context.addPath(path)
        context.drawPath(using: .fillStroke)
        
        context.setLineWidth(1)
        context.setStrokeColor(.cgColor(.icon))
        context.addPath(arrow)
        context.drawPath(using: .stroke)
    }
}
// swiftlint:enable operator_usage_whitespace

extension StatusBarAppProfileDropdownButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        guard context != .icon else {
            return .normal
        }

        if isConnected {
            switch context {
            case .border:
                return isHovered ? [.interactive, .hovered] : .normal
            case .background:
                if isHovered {
                    return [.interactive, .hovered]
                } else if dropDownExpanded {
                    return .strong
                } else {
                    return .transparent
                }
            default:
                break
            }
        } else {
            switch context {
            case .border:
                return .transparent
            case .background:
                return .interactive + (isHovered ? .hovered : [])
            default:
                break
            }
        }

        log.assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
