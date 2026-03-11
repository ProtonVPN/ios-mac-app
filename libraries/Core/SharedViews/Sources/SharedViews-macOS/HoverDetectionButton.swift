//
//  Created on 16/02/2022.
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

import Cocoa

open class HoverDetectionButton: NSButton {
    // Adds padding between text and button border
    @IBInspectable public var horizontalPadding: CGFloat = 0
    @IBInspectable public var verticalPadding: CGFloat = 0

    override open var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += horizontalPadding
        size.height += verticalPadding
        return size
    }

    override open var isEnabled: Bool {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }

    private var trackingArea: NSTrackingArea? {
        willSet {
            if trackingArea != nil {
                removeTrackingArea(trackingArea!)
            }
            if newValue != nil {
                addTrackingArea(newValue!)
            }
        }
    }

    open var isHovered: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    // MARK: - Life cycle

    override open func awakeFromNib() {
        super.awakeFromNib()

        setupView()
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    override open func updateTrackingAreas() {
        super.updateTrackingAreas()

        addMouseTracking()
    }

    override open func viewWillDraw() {
        super.viewWillDraw()
        layer?.masksToBounds = false
    }

    override open func resetCursorRects() {
        if isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override public func mouseEntered(with _: NSEvent) {
        if isEnabled {
            isHovered = true
        }
    }

    override public func mouseExited(with _: NSEvent) {
        isHovered = false
    }

    override public func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }

    // MARK: - Private

    private func setupView() {
        layer?.masksToBounds = false

        isBordered = false
        setButtonType(.momentaryChange)

        addMouseTracking()
    }

    private func addMouseTracking() {
        trackingArea = NSTrackingArea(rect: bounds, options: trackingOptions(), owner: self, userInfo: nil)
    }

    open func trackingOptions() -> NSTrackingArea.Options {
        [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow, NSTrackingArea.Options.activeAlways]
    }
}
