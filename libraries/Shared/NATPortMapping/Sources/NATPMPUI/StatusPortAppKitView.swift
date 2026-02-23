//
//  Created on 23/02/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import AppKit
import ProtonCoreUIFoundations
import Strings
import Theme

public final class StatusPortAppKitView: NSView {
    private static let copiedTooltipHideDelay: TimeInterval = 2

    public var portNumber: UInt16? {
        didSet {
            guard let portNumber else {
                titleLabel.stringValue = ""
                portLabel.stringValue = ""
                toolTip = nil
                return
            }

            titleLabel.stringValue = Localizable.pfActivePortStatus
            portLabel.stringValue = String(portNumber)
            toolTip = Localizable.pfCopyPortNumber
        }
    }

    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.textColor = .color(.text)
        label.font = .themeFont(.paragraph)
        return label
    }()

    private let indicatorImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.image = Asset.pfIndicator.image
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let portLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.textColor = .color(.text)
        label.font = .themeFont(.paragraph)
        return label
    }()

    private let copyImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.image = IconProvider.squares
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let spacerView: NSView = {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }()

    private let row: NSStackView = {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = Dimensions.rowSpacing
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }()

    private var trackingAreaRef: NSTrackingArea?
    private var hideTooltipTask: DispatchWorkItem?
    private lazy var copiedPopover: NSPopover = {
        let textField = NSTextField(labelWithString: Localizable.pfCopied)
        textField.textColor = .labelColor
        textField.font = .themeFont(.small)

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Dimensions.tooltipHorizontalInset),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Dimensions.tooltipHorizontalInset),
            textField.topAnchor.constraint(equalTo: container.topAnchor, constant: Dimensions.tooltipVerticalInset),
            textField.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Dimensions.tooltipVerticalInset),
        ])

        let viewController = NSViewController()
        viewController.view = container

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = viewController
        return popover
    }()

    // MARK: - Init

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = Dimensions.cornerRadius

        NSLayoutConstraint.activate([
            indicatorImageView.widthAnchor.constraint(equalToConstant: Dimensions.iconSize),
            indicatorImageView.heightAnchor.constraint(equalToConstant: Dimensions.iconSize),
        ])

        NSLayoutConstraint.activate([
            copyImageView.widthAnchor.constraint(equalToConstant: Dimensions.iconSize),
            copyImageView.heightAnchor.constraint(equalToConstant: Dimensions.iconSize),
        ])

        row.setViews([titleLabel, indicatorImageView, portLabel, copyImageView, spacerView], in: .leading)

        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Dimensions.rowInset),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Dimensions.rowInset),
            row.topAnchor.constraint(equalTo: topAnchor, constant: Dimensions.rowInset),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Dimensions.rowInset),
            heightAnchor.constraint(greaterThanOrEqualToConstant: Dimensions.minHeight),
        ])

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        row.setContentHuggingPriority(.required, for: .horizontal)
        row.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var mouseDownCanMoveWindow: Bool { false }

    override public func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }

    override public func mouseDown(with event: NSEvent) {
        guard let portNumber else {
            super.mouseDown(with: event)
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didCopy = pasteboard.setString(String(portNumber), forType: .string)
        if didCopy {
            showCopiedTooltip()
        }
    }

    override public func updateTrackingAreas() {
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let trackingAreaRef = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.trackingAreaRef = trackingAreaRef
        addTrackingArea(trackingAreaRef)
    }

    override public func mouseEntered(with _: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
    }

    override public func mouseExited(with _: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override public func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override public var intrinsicContentSize: NSSize {
        let size = row.fittingSize
        return NSSize(
            width: size.width + (Dimensions.rowInset * 2),
            height: max(Dimensions.minHeight, size.height + (Dimensions.rowInset * 2))
        )
    }

    private func showCopiedTooltip() {
        copiedPopover.show(relativeTo: bounds, of: self, preferredEdge: .maxY)

        hideTooltipTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.copiedPopover.performClose(nil)
        }
        hideTooltipTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.copiedTooltipHideDelay, execute: task)
    }
}

extension StatusPortAppKitView {
    private enum Dimensions {
        static let cornerRadius: CGFloat = 4
        static let iconSize: CGFloat = 12
        static let rowSpacing: CGFloat = 4
        static let rowInset: CGFloat = 2
        static let minHeight: CGFloat = 25
        static let tooltipHorizontalInset: CGFloat = 12
        static let tooltipVerticalInset: CGFloat = 8
    }
}
