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
            UncheckedSendable(
                NotificationCenter.default
                    .notifications(named: NSWindow.didResizeNotification)
                    .compactMap { $0.object as? NSWindow }
                    .filter { window in await MainActor.run { window.isMainWindow } }
                    .map { window in await MainActor.run { (window.frame.width, window.frame.height) } }
            )
            .eraseToStream()
        },
        windowDidEndLiveResize: {
            UncheckedSendable(
                NotificationCenter.default
                    .notifications(named: NSWindow.didEndLiveResizeNotification)
                    .compactMap { $0.object as? NSWindow }
                    .filter { window in await MainActor.run { window.isMainWindow } }
                    .map { window in await MainActor.run { (window.frame.width, window.styleMask.contains(.fullScreen)) } }
            )
            .eraseToStream()
        },
        windowWillEnterFullScreen: {
            UncheckedSendable(
                NotificationCenter.default
                    .notifications(named: NSWindow.willEnterFullScreenNotification)
                    .compactMap { $0.object as? NSWindow }
                    .filter { window in await MainActor.run { window.isMainWindow } }
                    .map { _ in () }
            )
            .eraseToStream()
        },
        windowWillExitFullScreen: {
            UncheckedSendable(
                NotificationCenter.default
                    .notifications(named: NSWindow.willExitFullScreenNotification)
                    .compactMap { $0.object as? NSWindow }
                    .filter { window in await MainActor.run { window.isMainWindow } }
                    .map { _ in () }
            )
            .eraseToStream()
        },
        occlusionStateChanged: {
            UncheckedSendable(
                NotificationCenter.default
                    .notifications(named: NSWindow.didChangeOcclusionStateNotification)
                    .compactMap { $0.object as? NSWindow }
                    .filter { window in await MainActor.run { window.isMainWindow } }
                    .map { _ in await MainActor.run { NSApp.occlusionState.contains(.visible) } }
            )
            .eraseToStream()
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
