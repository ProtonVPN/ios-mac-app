//
//  Created on 24/03/2026 by Max Kupetskyi.
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

struct SidebarEventsClient {
    var windowDidResize: @Sendable () -> AsyncStream<(width: CGFloat, height: CGFloat)>
    var windowDidEndLiveResize: @Sendable () -> AsyncStream<(width: CGFloat, isFullscreen: Bool)>
    var windowWillEnterFullScreen: @Sendable () -> AsyncStream<Void>
    var windowWillExitFullScreen: @Sendable () -> AsyncStream<Void>
    var occlusionStateChanged: @Sendable () -> AsyncStream<Bool>
}

extension SidebarEventsClient: DependencyKey {
    static let liveValue = SidebarEventsClient(
        windowDidResize: {
            AsyncStream { continuation in
                let observer = NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: nil,
                    queue: nil
                ) { notification in
                    guard let window = notification.object as? NSWindow, window.isMainWindow else { return }
                    continuation.yield((window.frame.width, window.frame.height))
                }
                continuation.onTermination = { _ in
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        },
        windowDidEndLiveResize: {
            AsyncStream { continuation in
                let observer = NotificationCenter.default.addObserver(
                    forName: NSWindow.didEndLiveResizeNotification,
                    object: nil,
                    queue: nil
                ) { notification in
                    guard let window = notification.object as? NSWindow, window.isMainWindow else { return }
                    continuation.yield((window.frame.width, window.styleMask.contains(.fullScreen)))
                }
                continuation.onTermination = { _ in
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        },
        windowWillEnterFullScreen: {
            AsyncStream { continuation in
                let observer = NotificationCenter.default.addObserver(
                    forName: NSWindow.willEnterFullScreenNotification,
                    object: nil,
                    queue: nil
                ) { notification in
                    guard let window = notification.object as? NSWindow, window.isMainWindow else { return }
                    continuation.yield(())
                }
                continuation.onTermination = { _ in
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        },
        windowWillExitFullScreen: {
            AsyncStream { continuation in
                let observer = NotificationCenter.default.addObserver(
                    forName: NSWindow.willExitFullScreenNotification,
                    object: nil,
                    queue: nil
                ) { notification in
                    guard let window = notification.object as? NSWindow, window.isMainWindow else { return }
                    continuation.yield(())
                }
                continuation.onTermination = { _ in
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        },
        occlusionStateChanged: {
            AsyncStream { continuation in
                let observer = NotificationCenter.default.addObserver(
                    forName: NSApplication.didChangeOcclusionStateNotification,
                    object: nil,
                    queue: nil
                ) { _ in
                    continuation.yield(NSApp.occlusionState.contains(.visible))
                }
                continuation.onTermination = { _ in
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        }
    )

    static let testValue = SidebarEventsClient(
        windowDidResize: { .finished },
        windowDidEndLiveResize: { .finished },
        windowWillEnterFullScreen: { .finished },
        windowWillExitFullScreen: { .finished },
        occlusionStateChanged: { .finished }
    )
}

extension DependencyValues {
    var sidebarEventsClient: SidebarEventsClient {
        get { self[SidebarEventsClient.self] }
        set { self[SidebarEventsClient.self] = newValue }
    }
}

private extension AsyncStream {
    static var finished: AsyncStream<Element> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
