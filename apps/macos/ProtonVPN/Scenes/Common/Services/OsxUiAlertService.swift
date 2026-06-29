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
import Combine
import Connection
import Domain
import Foundation
import LegacyCommon
import Observation
import Sharing
import Strings
import SwiftUI
import VPNAppCore

final class OsxUiAlertService {
    @Shared(.connectionState) private var connectionState: ConnectionState

    private var currentAlerts: [SystemAlert] = []
    /// Alerts pushed while no window was available to host them; flushed once one appears.
    private var pendingAlerts: [SystemAlert] = []
    private var isObservingWindowAvailability = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        startObservingConnectionState()
    }

    func displayAlert(_ alert: SystemAlert) {
        present(alert)
    }

    private func present(_ alert: SystemAlert) {
        guard alertIsNew(alert) else {
            updateOldAlert(with: alert)
            return
        }

        guard let window = hostWindow() else {
            // No window yet — e.g. a critical alert (force-upgrade, update-required) pushed at
            // launch or while the app runs menu-bar-only. Queue and retry when a window appears
            // rather than silently dropping it.
            enqueuePending(alert)
            return
        }

        show(alert, in: window)
    }

    /// Hosts a native SwiftUI `.alert` translated from the legacy `SystemAlert`.
    /// The host view is a zero-size ``NSHostingView`` mounted on the given window.
    private func show(_ alert: SystemAlert, in window: NSWindow) {
        currentAlerts.append(alert)

        let presentation = LegacyAlertPresentation()
        weak var weakHostingView: NSView?
        let hostingView = NSHostingView(
            rootView: LegacyAlertView(alert: alert, presentation: presentation) { [weak self] in
                weakHostingView?.removeFromSuperview()
                self?.dismissCompletion(alert)
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
        NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: \.isVisible)
    }

    // MARK: - Deferred presentation

    /// Defers an alert that arrived with no window to host it, and starts listening for a window to
    /// become available so it can be shown instead of lost.
    private func enqueuePending(_ alert: SystemAlert) {
        log.warning("No window available to present \(alert.className); deferring until one appears", category: .ui)
        pendingAlerts.append(alert)
        startObservingWindowAvailability()
    }

    private func startObservingWindowAvailability() {
        guard !isObservingWindowAvailability else { return }
        isObservingWindowAvailability = true

        Publishers.Merge(
            NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification),
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.flushPendingAlerts() }
        .store(in: &cancellables)
    }

    private func flushPendingAlerts() {
        guard !pendingAlerts.isEmpty, let window = hostWindow() else { return }
        let deferredAlerts = pendingAlerts
        pendingAlerts.removeAll()
        for alert in deferredAlerts where alertIsNew(alert) {
            show(alert, in: window)
        }
    }

    private func dismissAutoConnectionAlertsIfNeeded() {
        guard connectionState.isConnected else { return }
        currentAlerts.removeAll { alert in
            if alert.canDismissAutomaticallyOnConnection {
                alert.dismiss?()
                return true
            }
            return false
        }
    }

    private func startObservingConnectionState() {
        $connectionState
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.dismissAutoConnectionAlertsIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func alertIsNew(_ alert: SystemAlert) -> Bool {
        !(currentAlerts + pendingAlerts).contains { $0.className == alert.className }
    }

    private func updateOldAlert(with newAlert: SystemAlert) {
        // Match against shown and deferred alerts so a re-push updates whichever is tracked.
        let oldAlert = (currentAlerts + pendingAlerts).first { $0.className == newAlert.className }

        // In particular this means the alert's completion handlers will be updated
        oldAlert?.actions = newAlert.actions
    }

    private func dismissCompletion(_ alert: SystemAlert) {
        currentAlerts.removeAll { currentAlert in
            currentAlert.className == alert.className
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
