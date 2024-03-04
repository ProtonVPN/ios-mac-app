//
//  SwitchSideButton.swift
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

enum ButtonState: Int {
    case off, on
    
    func toggle() -> ButtonState {
        switch self {
        case .on: return .off
        case .off: return .on
        }
    }
}

protocol SwitchButtonDelegate: AnyObject {
    
    /// Asks delegate if button state should be switched. If completion if returned with false, button should not switch.
    func shouldToggle(_ button: NSButton, to value: ButtonState, completion: @escaping (Bool) -> Void)
    
    /// Called when the switch button is clicked
    func switchButtonClicked(_ button: NSButton)
}

extension SwitchButtonDelegate {
    public func shouldToggle(_ button: NSButton, to value: ButtonState, completion: (Bool) -> Void) {
        completion(true)
    }
}

class SwitchButton: NSView, CAAnimationDelegate {
    
    weak var delegate: SwitchButtonDelegate?
    var buttonView: NSButton?
    var innerView: NSView?
    
    var currentButtonState: ButtonState = .off {
        didSet {
            mask.drawBorder = currentButtonState == .off
        }
    }

    var isOn: Bool {
        return currentButtonState == .on
    }
    
    var buttonWidth: Int!
    var buttonHeight: Int!
    var knobPadding: Int!
    var knobSize: Int!
    
    var drawsUnderOverlay = true {
        didSet {
            initialSetup()
        }
    }
    
    var enabled: Bool = true {
        didSet {
            initialSetup()
        }
    }

    var maskColor: CGColor {
        get {
            mask.maskColor
        }
        set {
            mask.maskColor = newValue
        }
    }

    private var mask: ButtonMask!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        buttonWidth = Int(super.frame.width)
        buttonHeight = Int(super.frame.height)
        knobPadding = 4
        knobSize = buttonHeight - 2 * knobPadding
        
        initialSetup()
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        clipToBounds()

        let trackingArea = NSTrackingArea(rect: bounds,
                                          options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeAlways],
                                          owner: self,
                                          userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    override open func mouseEntered(with event: NSEvent) {
        if enabled {
            self.addCursorRect(bounds, cursor: NSCursor.pointingHand)
        }
    }
    
    override open func mouseExited(with event: NSEvent) {
        if enabled {
            self.addCursorRect(bounds, cursor: NSCursor.arrow)
        }
    }
    
    func initialSetup() {
        if !drawsUnderOverlay {
            wantsLayer = true
            layer?.cornerRadius = CGFloat(buttonHeight / 2)
        }
        
        subviews.forEach { $0.removeFromSuperview() }
        
        innerView = getInnerView()
        setInnerColor()
        buttonView = getButtonView()
        
        buttonView?.addSubview(innerView!)

        mask = ButtonMask(frame: bounds)
        mask.drawBorder = !isOn
        
        if drawsUnderOverlay {
            buttonView?.addSubview(mask)
        }
        
        addSubview(buttonView!)
    }
    
    func registerDelegate(_ delegate: SwitchButtonDelegate) {
        self.delegate = delegate
        self.setState(currentButtonState, animated: false)
    }
    
    func setState(_ state: ButtonState, animated: Bool = false) {
        currentButtonState = state
        if animated {
            DarkAppearance {
                resolveAnimation()
            }
        } else {
            switchWithoutAnimation()
        }
        NSAccessibility.post(element: self, notification: NSAccessibility.Notification.valueChanged)
    }
    
    func resolveAnimation() {
        switch currentButtonState {
        case .on:
            innerView?.animator().frame.origin = NSPoint(x: 0, y: 0)
            innerView?.animateBackgroundColor(self.cgColor(.background), delegate: self)
        case .off:
            innerView?.animator().frame.origin = NSPoint(x: -1 * (Int(buttonWidth - knobSize) - knobPadding * 2), y: 0)
            innerView?.animateBackgroundColor(self.cgColor(.background), delegate: self)
        }
    }
    
    func animationDidStart(_ anim: CAAnimation) {
        setInnerColor()
    }
    
    func registerButtonHandlers(_ button: NSButton) {
        button.target = self
        button.action = #selector(buttonClicked(_:))
    }
    
    @objc func buttonClicked(_ button: NSButton) {
        guard let delegate = self.delegate, enabled else {
            return
        }
        
        let newState = ButtonState.toggle(currentButtonState)()
        delegate.shouldToggle(button, to: newState) { shouldToggle in
            guard shouldToggle else {
                return
            }
            self.setState(newState, animated: true)
            self.delegate?.switchButtonClicked(button)
        }
    }
    
    // MARK: - Private
    
    fileprivate func getButtonView() -> NSButton {
        let button = NSButton(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight))
        
        button.title = ""
     
        registerButtonHandlers(button)
        
        return button
    }
    
    fileprivate func getInnerView() -> NSView {
        let innerView = NSView(frame: NSRect(x: 0, y: 0, width: (buttonWidth - knobSize) * 2 + knobSize, height: buttonHeight))
        
        innerView.wantsLayer = true
        
        let knobView = getKnobView()
        
        innerView.addSubview(knobView)
        
        return innerView
    }
    
    fileprivate func getKnobView() -> NSView {
        let knobView = NSView(frame: NSRect(x: Int(buttonWidth - knobSize) - knobPadding, y: knobPadding, width: knobSize, height: knobSize))

        knobView.wantsLayer = true
        knobView.layer?.cornerRadius = CGFloat(knobSize / 2)
        DarkAppearance {
            knobView.layer?.backgroundColor = self.cgColor(.icon)
        }
        
        return knobView
    }
    
    private func setInnerColor() {
        DarkAppearance {
            self.innerView?.layer?.backgroundColor = self.cgColor(.background)
        }
    }
    
    private func switchWithoutAnimation() {
        switch currentButtonState {
        case .on:
            innerView?.frame.origin = NSPoint(x: 0, y: 0)
        case .off:
            innerView?.frame.origin = NSPoint(x: -1 * (Int(buttonWidth - knobSize) - knobPadding * 2), y: 0)
        }
        
        setInnerColor()
    }
    
    // MARK: - Accessibility
    
    override func accessibilityValue() -> Any? {
        return currentButtonState
    }
    
    override func accessibilityChildren() -> [Any]? {
        return nil
    }
    
    override func isAccessibilityElement() -> Bool {
        return true
    }
}

extension SwitchButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .background:
            if !enabled {
                return [.interactive, .weak, .disabled]
            } else if isOn {
                return .interactive
            }
            return .normal
        case .icon:
            return .normal
        default:
            break
        }
        log.assertionFailure("Unhandled context: \(context)")
        return .normal
    }
}
