//
//  StatusMenuWindowController.swift
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

import AppKit
import Theme

class StatusWindow: NSPanel {
    
    override var canBecomeKey: Bool {
        return true
    }
}

// Responsible for the status icon itself and the window for the status bar app
final class StatusMenuWindowController: WindowController {

    private var windowModel: StatusMenuWindowModel?
    
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusMenu = NSMenu()
    
    private let iconManager: StatusBarIconBlinker

    private var eventsMonitor: Any?

    var windowIsVisible: Bool {
        return window?.isVisible == true
    }

    var lastOpenApplication: NSRunningApplication?

    weak var windowService: WindowService?
    
    override var contentViewController: NSViewController? {
        didSet {
            if let viewController = contentViewController {
                window = StatusWindow(contentViewController: viewController)
                setupWindow()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    override init(window: NSWindow?) {
        iconManager = StatusBarIconBlinker(statusItem: statusItem, statusIcon: .unknown)
        
        super.init(window: window)
        
        monitorsKeyEvents = true
    }
    
    deinit {
        eventsMonitor.map { NSEvent.removeMonitor($0) }
    }
    
    func update(with windowModel: StatusMenuWindowModel) {
        self.windowModel = windowModel
        
        contentViewController = windowModel.statusMenuViewController
        
        setupIcon()
        
        self.windowModel?.contentChanged = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.setupIcon()
            }
        }
        
        self.eventsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
            switch event.type {
            case .leftMouseDown:
                if event.isStatusItemClicked(event: event) == self?.statusItem {
                    self?.togglePopover()
                }
            case .keyDown where event.keyCode == KeyCode.escape.rawValue:
                self?.dismissPopover()
            default:
                break
            }
            
            return event
        }
    }
    
    private func setupIcon() {
        iconManager.setImage(windowModel?.statusIcon ?? .unknown)
        iconManager.isBlinking = windowModel?.isStatusIconBlinking ?? false
        NSApp.applicationIconImage = (windowModel?.appIcon ?? .active).image
    }
    
    private func togglePopover() {
        if windowIsVisible {
            dismissPopover()
        } else {
            showPopover()
        }
    }
    
    private func showPopover() {
        guard let button = statusItem.button, let frame = button.window?.frame else { return }
        
        button.isHighlighted = true
        showWindow(self, relativeTo: frame)
        
        windowModel?.requiresRefreshes(true)
    }
    
    private func dismissPopover() {
        if windowIsVisible {
            close()
            statusItem.button?.isHighlighted = false
        }
        
        windowModel?.requiresRefreshes(false)
    }
    
    private func showWindow(_ sender: Any?, relativeTo frame: CGRect) {
        super.showWindow(sender)
        
        guard let window = window else { return }
        
        let height: CGFloat = 436 // positions countries so that 3.5 rows are showing
        let width: CGFloat = 300
        var extensionFrame = CGRect(x: frame.minX, y: frame.minY - height, width: width, height: height)
        if let screenFrame = statusItem.button?.window?.screen?.visibleFrame, let buttonWidth = statusItem.button?.frame.width {
            let padding: CGFloat = 20
            if extensionFrame.maxX + padding > screenFrame.maxX {
                extensionFrame.origin.x -= (width - buttonWidth)
            }
        }
        window.setFrame(extensionFrame, display: true)
        window.makeKeyAndOrderFront(sender)
    }
    
    override func close() {
        window?.orderOut(nil)
    }
    
    private func setupWindow() {
        guard let window = window else {
            return
        }

        window.delegate = self
        window.acceptsMouseMovedEvents = true
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hidesOnDeactivate = false
        window.hasShadow = true
        
        window.styleMask = .nonactivatingPanel
        window.level = .popUpMenu
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.appearance = NSAppearance(named: .darkAqua)
    }
}

extension StatusMenuWindowController {
    override func windowWillClose(_ notification: Notification) {
        windowService?.windowWillClose(self)
        dismissPopover()
    }
    
    func windowDidResignKey(_ notification: Notification) {
        dismissPopover()
    }
}

extension NSStatusBarButton {
    
    override open func mouseDown(with event: NSEvent) {
        // allow StatusMenuController to manage the behavour of clicking
        return
    }
}

extension NSEvent {
    
    func isStatusItemClicked(event: NSEvent) -> NSStatusItem? {
        guard let window = window else { return nil }
        guard window.className.hasPrefix("NSStatusBar"), window.className.hasSuffix("Window") else { return nil }
        guard event.eventNumber != 1337 else { return nil } // Bartender app event (avoid Bartender events from being misinterpreted as clicks on our app icon)
        return window.value(forKey: "statusItem") as? NSStatusItem
    }
}

extension StatusIcon {
    var image: NSImage {
        var result: NSImage
        switch self {
        case .connected: result = Theme.Asset.connected.image
        case .disconnected: result = Theme.Asset.disconnected.image
        case .connecting: result = Theme.Asset.idle.image
        case .unknown: result = Theme.Asset.emptyIcon.image
        }

        result = result
            .resize(newWidth: Self.size, newHeight: Self.size)
        result.isTemplate = true
        return result
    }
}

extension AppIcon {
#if STAGING // use Debug icon for staging builds
    static let appIconConnected = Theme.Asset.dynamicAppIconDebugConnected.image
    static let appIconDisconnected = Theme.Asset.dynamicAppIconDebugDisconnected.image
#else
    static let appIconConnected = Theme.Asset.dynamicAppIconConnected.image
    static let appIconDisconnected = Theme.Asset.dynamicAppIconDisconnected.image
#endif
    var image: NSImage {
        switch self {
        case .active:
            return AppIcon.appIconConnected
        case .disconnected:
            return AppIcon.appIconDisconnected
        }
    }
}

class StatusBarIconBlinker {
    
    private var statusItem: NSStatusItem
    private var statusIcon: StatusIcon
    
    private var emptyImage: NSImage = StatusIcon.unknown.image
    private var interval: TimeInterval = AppConstants.Time.statusIconBlink
    private var timer: Timer?
    
    public var isBlinking: Bool = false {
        didSet {
            if isBlinking && timer == nil {
                start()
                return
            }
            if !isBlinking && timer != nil {
                stop()
                return
            }
        }
    }
    
    public init(statusItem: NSStatusItem, statusIcon: StatusIcon) {
        self.statusItem = statusItem
        self.statusIcon = statusIcon
    }
    
    public func setImage(_ statusIcon: StatusIcon) {
        if statusIcon != self.statusIcon {
            self.statusIcon = statusIcon
            if statusItem.button?.image != emptyImage {
                statusItem.button?.image = statusIcon.image
            }
        }
    }
    
    private func start() {
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
    }
    
    private func stop() {
        timer?.invalidate()
        timer = nil
        statusItem.button?.image = statusIcon.image
    }
    
    @objc func fireTimer() {
        if statusItem.button?.image == emptyImage {
            statusItem.button?.image = statusIcon.image
        } else {
            statusItem.button?.image = emptyImage
        }
    }
    
}
