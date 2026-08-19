//
//  Created on 19/08/2026 by Max Kupetskyi.
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
import Dependencies
import Foundation

/// Whether the main window is on screen, so features can stop working while nobody can see them.
///
/// `viewDidDisappear` does not run when another window covers ours or when the user hides the app, so
/// a view that repeats work on a timer cannot tell it has become pointless. AppKit reports that
/// through the window's occlusion state instead.
struct WindowVisibilityClient {
    /// `true` while the sidebar window is on screen, sent once at the start and on every change.
    var isVisible: @Sendable () -> AsyncStream<Bool>
}

@MainActor
private func sidebarWindow() -> NSWindow? {
    NSApp.windows.first { $0.windowController is SidebarWindowController }
}

@MainActor
private func isSidebarWindow(_ window: NSWindow) -> Bool {
    window.windowController is SidebarWindowController
}

extension WindowVisibilityClient: DependencyKey {
    static let liveValue = WindowVisibilityClient(
        isVisible: {
            AsyncStream { continuation in
                let task = Task { @MainActor in
                    // The window may already be covered by the time anyone subscribes, and AppKit
                    // only reports changes, so start from what is true now.
                    continuation.yield(sidebarWindow()?.occlusionState.contains(.visible) ?? true)

                    let notifications = NotificationCenter.default
                        .notifications(named: NSWindow.didChangeOcclusionStateNotification)
                    for await notification in notifications {
                        guard let window = notification.object as? NSWindow,
                              isSidebarWindow(window)
                        else { continue }
                        continuation.yield(window.occlusionState.contains(.visible))
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    )

    static let testValue = WindowVisibilityClient(
        isVisible: {
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    )
}

extension DependencyValues {
    var windowVisibility: WindowVisibilityClient {
        get { self[WindowVisibilityClient.self] }
        set { self[WindowVisibilityClient.self] = newValue }
    }
}
