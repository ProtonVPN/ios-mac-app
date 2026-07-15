//
//  OsxUiAlertService.swift
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
import Domain
import Foundation
import Observation
import Strings
import SwiftUI
import VPNAppCore

final class OsxUiAlertService {
    /// Alerts currently shown as sheets on a regular window.
    private var sheetAlerts: [SystemAlert] = []

    /// Alerts currently shown as standalone alert windows, keyed by alert class.
    private var alertWindows: [String: SystemAlertWindowController] = [:]

    func displayAlert(_ alert: SystemAlert) {
        present(alert)
    }

    private func present(_ alert: SystemAlert) {
        guard alertIsNew(alert) else {
            updateOldAlert(with: alert)
            return
        }

        if let window = hostWindow() {
            if NSApp.keyWindow is StatusWindow {
                // Triggered from the non-activating popover, so the app may be inactive and
                // a sheet on a background window would be unreachable. Activate and bring the
                // host forward; taking keyboard focus (key-window status) away from the popover
                // makes it close itself — StatusMenuWindowController dismisses it on
                // windowDidResignKey, matching the old NSAlert behaviour.
                NSRunningApplication.current.activate(options: [.activateAllWindows])
                window.makeKeyAndOrderFront(nil)
            }
            showAsSheet(alert, in: window)
        } else {
            // No window can host a sheet (popover-only or none at all): show a standalone
            // window styled like the native alert instead.
            showAsWindow(alert)
        }
    }

    // MARK: - Sheet path (a regular window exists)

    /// Presents the alert as a native SwiftUI `.alert` hosted by a zero-size
    /// `NSHostingView` mounted on the given window.
    private func showAsSheet(_ alert: SystemAlert, in window: NSWindow) {
        log.info("Presenting \(alert.className) as a sheet on \(window.className)", category: .ui)
        sheetAlerts.append(alert)

        let presentation = LegacyAlertPresentation()
        weak var weakHostingView: NSView?
        let hostingView = NSHostingView(
            rootView: LegacyAlertView(alert: alert, presentation: presentation) { [weak self] in
                weakHostingView?.removeFromSuperview()
                self?.sheetAlerts.removeAll { $0.className == alert.className }
            }
        )
        weakHostingView = hostingView
        hostingView.frame = .zero
        window.contentView?.addSubview(hostingView)

        // Allows the alert to be dismissed programmatically (e.g. auto-dismiss on connection).
        alert.dismiss = { presentation.isPresented = false }

        if alert.activatingApp {
            NSRunningApplication.current.activate(options: [.activateAllWindows])
        }
    }

    private func hostWindow() -> NSWindow? {
        let candidates = [NSApp.keyWindow, NSApp.mainWindow] + NSApp.windows.filter(\.isVisible)
        return candidates.compactMap { $0 }.first(where: canHostAlertSheet)
    }

    /// Whether a window can host a SwiftUI `.alert` sheet: it must be titled and able to
    /// become key. This excludes the popover panel (borderless; a sheet just dims it), the
    /// menu-bar status item window (always visible in `NSApp.windows` — alerts used to
    /// attach to the menu bar itself), standalone alert windows, and other chrome windows.
    private func canHostAlertSheet(_ window: NSWindow) -> Bool {
        window.styleMask.contains(.titled)
            && window.canBecomeKey
            && !(window is StatusWindow)
    }

    // MARK: - Window path (no window can host a sheet)

    private func showAsWindow(_ alert: SystemAlert) {
        log.info("Presenting \(alert.className) as a standalone alert window", category: .ui)

        let key = alert.className
        let controller = SystemAlertWindowController(alert: alert) { [weak self] in
            self?.alertWindows.removeValue(forKey: key)
        }
        alertWindows[key] = controller

        alert.dismiss = { [weak controller] in controller?.dismiss() }

        let screen = targetScreen()
        controller.present(
            on: screen,
            anchorMidX: statusItemWindow(on: screen)?.frame.midX,
            cascadeIndex: alertWindows.count - 1
        )
    }

    /// The screen the user is interacting with: under the pointer first (they just clicked
    /// the status item there), then the one with keyboard focus, then any.
    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    /// The menu-bar window hosting this app's status item on the given screen, located by
    /// class name — the same heuristic `NSEvent.isStatusItemClicked` uses.
    ///
    /// The match requires the window to actually sit in this screen's menu-bar strip:
    /// after a display change (e.g. clamshell switch) `NSApp.windows` can still hold a
    /// stale status-bar window with a frame from the old arrangement, and using its
    /// coordinates puts the alert in the wrong place. No verified match means no anchor —
    /// the alert then centres on the screen, which beats a confidently wrong position.
    private func statusItemWindow(on screen: NSScreen?) -> NSWindow? {
        guard let screen else { return nil }

        let menuBarStrip = NSRect(
            x: screen.frame.minX,
            y: screen.visibleFrame.maxY,
            width: screen.frame.width,
            height: max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        )
        guard !menuBarStrip.isEmpty else { return nil } // e.g. menu bar set to auto-hide

        return NSApp.windows.first {
            $0.className.hasPrefix("NSStatusBar") && $0.className.hasSuffix("Window")
                && $0.isVisible
                && $0.frame.intersects(menuBarStrip)
        }
    }

    // MARK: - Alert bookkeeping

    private func alertIsNew(_ alert: SystemAlert) -> Bool {
        alertWindows[alert.className] == nil
            && !sheetAlerts.contains { $0.className == alert.className }
    }

    private func updateOldAlert(with newAlert: SystemAlert) {
        // Both presentation paths resolve the tapped action from the alert object at click
        // time, so replacing the actions swaps in the new completion handlers.
        if let oldAlert = sheetAlerts.first(where: { $0.className == newAlert.className }) {
            oldAlert.actions = newAlert.actions
        } else if let controller = alertWindows[newAlert.className] {
            controller.update(actions: newAlert.actions)
            // A re-push means something tried to show this alert again; it may be buried
            // behind other apps' windows — bring it back.
            controller.bringToFront()
        }
    }
}

// MARK: - SwiftUI alert host

@Observable
private final class LegacyAlertPresentation {
    var isPresented = true
}

/// Converts a legacy `SystemAlert` into a native SwiftUI `.alert`
///
/// zero-size host view on the key window so SwiftUI can present the alert
/// window-modally; the underlying view is never visible
private struct LegacyAlertView: View {
    let alert: SystemAlert
    @Bindable var presentation: LegacyAlertPresentation
    let onDismiss: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .alert(alert.title ?? "", isPresented: $presentation.isPresented) {
                if alert.actions.isEmpty {
                    Button(Localizable.ok) {}
                } else {
                    ForEach(Array(alert.actions.enumerated()), id: \.offset) { _, action in
                        Button(action.title, role: action.style.buttonRole) {
                            action.handler?()
                        }
                    }
                }
            } message: {
                if let message = alert.message, !message.isEmpty {
                    Text(message)
                }
            }
            .onChange(of: presentation.isPresented) { _, isPresented in
                if !isPresented {
                    onDismiss()
                }
            }
    }
}

private extension PrimaryActionType {
    /// Maps the legacy action style to a SwiftUI alert button role.
    var buttonRole: ButtonRole? {
        switch self {
        case .destructive: .destructive
        case .cancel: .cancel
        case .confirmative, .secondary: nil
        }
    }
}
