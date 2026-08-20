//
//  Created on 23/06/2026.
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

#if os(macOS)
    import Dependencies
    import Domain
    import ExtensionIPC
    import Foundation
    import IOSurface
    import IPCErgonomics
    import Logging
    import os

    fileprivate let log: Logging.Logger = .init(label: "ProtonVPN.XPCClient.logger")

    /// Why a tunnel-data region could not be attached. The XPC error itself only exists inside the connection's error
    /// handler, which logs it there.
    public enum TunnelDataXPCError: Error, Sendable {
        /// The remote proxy could not be built, so no message reached the extension.
        case proxyUnavailable
        /// The connection reported an error instead of delivering the reply.
        case connectionFailed
        /// The extension answered, but had no surface to hand over.
        case noSurfaceAvailable
    }

    /// macOS XPC client for the extension's `TunnelDataXPCService`, which fetches the shared `IOSurface` and sets it as
    /// the backing memory for the ``TunnelDataStore``.
    ///
    /// The extension allocates one surface per process and announces its id as the tunnel-data notification's state.
    /// While running, this client follows those announcements and fetches whichever surface the app does not already
    /// hold. Constructing it does nothing on its own until ``resume()``.
    public final class TunnelDataXPCClient: @unchecked Sendable {
        /// The reply to one `fetchTunnelDataSurface` call, resumed by either the reply block or the connection's error
        /// handler.
        private typealias Fetch = CheckedContinuation<IOSurfaceID, any Error>

        @Dependency(\.extensionIPC) private var extensionIPC

        private let machServiceName: String

        /// The task following announcements, when running. Every fetch happens inside it, so a burst of announcements
        /// can never produce overlapping fetches.
        private let watch = OSAllocatedUnfairLock<Task<Void, Never>?>(uncheckedState: nil)

        public init(machServiceName: String) {
            self.machServiceName = machServiceName
        }

        deinit {
            cancel()
        }

        /// Starts following the extension's announcements, attaching the region each one names when it differs from the
        /// one the app has mapped. Checks once up front, so an extension already running when this is called is picked
        /// up without waiting for its next write. Calling this while already following does nothing.
        public func resume() {
            watch.withLockUnchecked { task in
                guard task == nil else { return }
                task = Task { [weak self] in await self?.followAnnouncements() }
            }
        }

        /// Stops following announcements. Whatever is mapped stays mapped, and ``resume()`` picks up from whatever the
        /// extension has announced in the meantime.
        public func cancel() {
            watch.withLockUnchecked { task in
                task?.cancel()
                task = nil
            }
        }

        // MARK: - Private

        /// Every channel write the extension makes posts the tunnel-data notification, so a connection coming up
        /// produces a burst of them while a fetch is still in the air. Let the posts buffer in the stream, and discard
        /// any updates naming the region we're already dealing with.
        private func followAnnouncements() async {
            // Built before the first check so an announcement landing between the two is not lost. The stream registers
            // its observer as it is created, not when it is first iterated.
            let posts = IPCNotifications.streamRawState(.tunnelData)
            await attachAnnouncedRegion()
            for await _ in posts {
                await attachAnnouncedRegion()
            }
        }

        /// Reads the announced id rather than the value a post carried, so a buffered announcement is only a wakeup and
        /// cannot act on an id that has since moved on.
        private func attachAnnouncedRegion() async {
            let announced = IPCNotifications.getRawState(.tunnelData)
            let mapped = extensionIPC.currentRegionID()

            // Either nothing is mapped, or the value has changed and isn't simply being cleared
            let needsRegion = mapped == nil || (announced != 0 && announced != mapped)
            guard needsRegion else { return }

            do {
                let attached = try await attachRegion()
                log.info("Attached tunnel-data IOSurface region \(attached) from extension")
            } catch {
                // Recovery is the next announcement, which only a running extension produces.
                log.error("Could not attach tunnel-data region: \(error)")
            }
        }

        /// Each fetch gets its own connection, discarded as soon as the reply lands. The app maps one region per
        /// extension process, so this runs about as often as the extension is replaced, and no connection outlives its
        /// call for a late reply to tear down by mistake.
        private func attachRegion() async throws -> IOSurfaceID {
            // Bound locally so the escaping XPC callbacks below do not capture `self`.
            let extensionIPC = extensionIPC
            let serviceName = machServiceName
            let connection = makeConnection()
            defer { connection.invalidate() }

            // One message per proxy, so XPC calls exactly one of the reply block and the error handler.
            return try await withCheckedThrowingContinuation { (continuation: Fetch) in
                guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                    log.error("ProTUN XPC proxy error for \(serviceName): \(String(describing: error))")
                    continuation.resume(throwing: TunnelDataXPCError.connectionFailed)
                }) as? TunnelDataXPCProtocol else {
                    return continuation.resume(throwing: TunnelDataXPCError.proxyUnavailable)
                }

                proxy.fetchTunnelDataSurface { surface in
                    guard let surface else {
                        return continuation.resume(throwing: TunnelDataXPCError.noSurfaceAvailable)
                    }
                    let region = surface as IOSurfaceRef
                    extensionIPC.attachRegion(region)
                    continuation.resume(returning: IOSurfaceGetID(region))
                }
            }
        }

        private func makeConnection() -> NSXPCConnection {
            let connection = NSXPCConnection(machServiceName: machServiceName, options: [])
            let interface = NSXPCInterface(with: TunnelDataXPCProtocol.self)

            // `IOSurface` is `NSSecureCoding`, but NSXPC still needs it whitelisted on the reply argument to decode it.
            interface.setClasses(
                NSSet(array: [IOSurface.self]) as! Set<AnyHashable>,
                for: #selector(TunnelDataXPCProtocol.fetchTunnelDataSurface(_:)),
                argumentIndex: 0,
                ofReply: true
            )
            connection.remoteObjectInterface = interface
            connection.resume()
            return connection
        }
    }
#endif
