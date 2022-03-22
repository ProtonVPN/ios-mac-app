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
import vpncore

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
        context.setStrokeColor(self.cgColor(.icon))
        context.setFillColor(self.cgColor(.background))

        if isConnected {
            ib = NSRect(x: bounds.origin.x + lw/2, y: bounds.origin.y + lw/2, width: bounds.width - lw, height: bounds.height - lw)
        } else {
            ib = NSRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width - lw/2, height: bounds.height)
        }
        
        context.setLineWidth(lw)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: ib.maxX, y: ib.maxY))

        let r = AppTheme.ButtonConstants.cornerRadius
        if dropDownExpanded {
            // Bottom border (without corner)
            path.addLine(to: CGPoint(x: ib.minX, y: ib.maxY))
            // Left border
            path.addLine(to: CGPoint(x: ib.minX, y: ib.minY + r))
            // Top-left corner
            path.addArc(center: CGPoint(x: ib.minX + r, y: ib.minY + r), radius: r,
                        startAngle: .pi, endAngle: .pi*3/2, clockwise: false)
        } else {
            // Bottom border
            path.addLine(to: CGPoint(x: ib.minX + r, y: ib.maxY))
            // Bottom-left corner
            path.addArc(center: CGPoint(x: ib.minX + r, y: ib.minY + ib.height - r), radius: r,
                        startAngle: .pi/2, endAngle: .pi, clockwise: false)
            // Left border
            path.addLine(to: CGPoint(x: ib.minX, y: ib.minY + r))
            // Top-left corner
            path.addArc(center: CGPoint(x: ib.minX + r, y: ib.minY + r), radius: r,
                        startAngle: .pi, endAngle: .pi*3/2, clockwise: false)
        }
        
        path.addLine(to: CGPoint(x: ib.maxX, y: ib.minY))
        path.closeSubpath()
        
        context.addPath(path)
        context.drawPath(using: .fillStroke)

        let buttonTitle = self.style(isConnected ? LocalizedString.disconnect : LocalizedString.quickConnect)
        let textHeight = buttonTitle.size().height
        buttonTitle.draw(in: CGRect(x: bounds.height/2, y: (bounds.height - textHeight) / 2, width: bounds.width - bounds.height/2, height: textHeight))
    }
}
// swiftlint:enable operator_usage_whitespace

extension StatusBarAppConnectButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        if isConnected {
            switch context {
            case .text:
                return .normal
            case .icon:
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
            case .icon:
                return .transparent
            case .background:
                return .interactive + (isHovered ? .hovered : [])
            default:
                break
            }
        }
        assertionFailure("Context not handled: \(context)")
        return .normal
    }
}

// swiftlint:disable operator_usage_whitespace
class StatusBarAppProfileDropdownButton: LargeDropdownButton {
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let lw: CGFloat = 2
        let ib: CGRect
        context.setStrokeColor(self.cgColor(.icon))
        context.setFillColor(self.cgColor(.background))
        if isConnected {
            ib = NSRect(x: bounds.origin.x - lw/2, y: bounds.origin.y + lw/2, width: bounds.width - lw/2, height: bounds.height - lw)
        } else {
            ib = NSRect(x: bounds.origin.x + lw/2, y: bounds.origin.y, width: bounds.width - lw/2, height: bounds.height)
        }
        
        context.setLineWidth(lw)

        let r = AppTheme.ButtonConstants.cornerRadius
        let path = CGMutablePath()
        path.move(to: CGPoint(x: ib.minX, y: ib.minY))
        path.addLine(to: CGPoint(x: ib.maxX - ib.height/2, y: ib.minY))
        // Top-right corner
        path.addArc(center: CGPoint(x: ib.maxX - r, y: ib.minY + r), radius: r, startAngle: .pi*3/2, endAngle: 0, clockwise: false)

        if dropDownExpanded {
            // Right border
            path.addLine(to: CGPoint(x: ib.maxX, y: ib.maxY))
        } else {
            // Right border
            path.addLine(to: CGPoint(x: ib.maxX, y: ib.maxY - r))
            // Bottom-right corner
            path.addArc(center: CGPoint(x: ib.maxX - r, y: ib.maxY - r), radius: r, startAngle: 0, endAngle: .pi/2, clockwise: false)
        }
        
        path.addLine(to: CGPoint(x: ib.minX, y: ib.maxY))
        path.closeSubpath()
        
        let ah: CGFloat = dropDownExpanded ? -4 : 4 // arrowHeight
        let midX: CGFloat = bounds.midX - 2
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
        if isConnected {
            switch context {
            case .icon:
                return isHovered ? [.weak, .interactive, .hovered] : .normal
            case .background:
                return .transparent
            default:
                break
            }
        } else {
            switch context {
            case .icon:
                return .transparent
            case .background:
                return .interactive + (isHovered ? .hovered : [])
            default:
                break
            }
        }

        assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
