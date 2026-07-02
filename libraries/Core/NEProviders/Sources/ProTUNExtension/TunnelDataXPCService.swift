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
    import ExtensionIPC
    import Foundation
    import IOSurface
    import IPCErgonomics
    import ExtensionSync
    import IPCDefinitions
    import os
    import XPCAuditToken

    /// Used on macOS to establish a shared memory region between the System Extension and the the app/other extensions
    ///
    /// A system extension can't share an app-group container with the app, so instead of a file `mmap`, the extension
    /// allocates an `IOSurface`, backs the ``ExtensionIPCClient`` with it, and hands that to client apps + extensions instead
    public final class TunnelDataXPCService: Sendable {
        /// All mutable, non-``Sendable`` state, accessed only behind the lock.
        private struct State {
            var surface: IOSurfaceRef?
            var listener: NSXPCListener?
            /// A newly-accepted connection invalidates the previous one.
            /// (TODO: widget/shortcut support on macOS - VPNAPPL-3567)
            var currentConnection: NSXPCConnection?
            /// Keep a reference to the listener delegate here, since `NSXPCListener.delegate` is `weak`.
            var listenerDelegate: Listener?
        }

        fileprivate let log: @Sendable (String) -> Void

        private let machServiceName: String
        private let state = OSAllocatedUnfairLock<State>(uncheckedState: State())

        public init(machServiceName: String, log: @escaping @Sendable (String) -> Void = { _ in }) {
            self.machServiceName = machServiceName
            self.log = log

            let surface = IOSurfaceBackedRegion.makeIOSurface(size: MemoryLayout<IPCTunnelData>.size)
            state.withLockUnchecked { $0.surface = surface }

            // Immediately attach the raw channel region on startup.
            if let surface {
                @Dependency(\.extensionIPCServer) var extensionIPCServer
                extensionIPCServer.attachIOSurfaceBackedRegion(surface)
            } else {
                log("Failed to allocate tunnel-data IOSurface; the macOS app will not receive live tunnel data")
            }
        }

        public func startListener() {
            log("Starting tunnel-data XPC listener for mach service \(machServiceName)")
            let delegate = Listener(service: self)
            let listener = NSXPCListener(machServiceName: machServiceName)
            listener.delegate = delegate
            listener.resume()
            state.withLockUnchecked {
                $0.listener = listener
                $0.listenerDelegate = delegate
            }
        }

        fileprivate var currentSurface: IOSurfaceRef? {
            state.withLockUnchecked { $0.surface }
        }

        /// Adopts `connection` as the current client, invalidating any previous ones.
        fileprivate func adopt(_ connection: NSXPCConnection) {
            let previous = state.withLockUnchecked { state -> NSXPCConnection? in
                let previous = state.currentConnection
                state.currentConnection = connection
                return previous
            }
            previous?.invalidate()
        }

        /// Called from the invalidation/interruption handler, so a late teardown of an old connection can't
        /// clobber a newer one.
        fileprivate func release(_ connection: NSXPCConnection) {
            state.withLockUnchecked { state in
                if state.currentConnection === connection {
                    state.currentConnection = nil
                }
            }
        }
    }

    private extension TunnelDataXPCService {
        /// The bridge to ObjC that lets us use delegates + the `exportedObject` property while still conforming to ``Sendable``.
        final class Listener: NSObject, NSXPCListenerDelegate, TunnelDataXPCProtocol {
            private unowned let service: TunnelDataXPCService

            init(service: TunnelDataXPCService) {
                self.service = service
            }

            func fetchTunnelDataSurface(_ reply: @escaping (IOSurface?) -> Void) {
                reply(service.currentSurface as IOSurface?)
            }

            func listener(_: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
                // Audit-trailer check: only accept clients that are signed with the same identity as us.
                let pid = newConnection.processIdentifier
                do {
                    let matches = try CodeSignatureComparator.codeSignatureMatches(auditToken: newConnection.auditToken)
                    #if DEBUG
                        if !matches {
                            service.log("Code signature of pid \(pid) does not match. Proceeding anyway (debug build).")
                        }
                    #else
                        guard matches else {
                            service.log("Refusing XPC connection with pid \(pid): code signature does not match")
                            return false
                        }
                    #endif
                } catch {
                    service.log("Code signing error while verifying pid \(pid): \(String(describing: error))")
                    #if !DEBUG
                        return false
                    #endif
                }

                let interface = NSXPCInterface(with: TunnelDataXPCProtocol.self)
                // `IOSurface` is `NSSecureCoding`, but NSXPC still needs it explicitly whitelisted for the reply argument.
                interface.setClasses(
                    NSSet(array: [IOSurface.self]) as! Set<AnyHashable>,
                    for: #selector(TunnelDataXPCProtocol.fetchTunnelDataSurface(_:)),
                    argumentIndex: 0,
                    ofReply: true
                )
                newConnection.exportedInterface = interface
                newConnection.exportedObject = self
                newConnection.invalidationHandler = { [weak self, weak newConnection] in
                    guard let newConnection else { return }
                    self?.service.release(newConnection)
                }
                newConnection.interruptionHandler = { [weak self, weak newConnection] in
                    guard let newConnection else { return }
                    self?.service.release(newConnection)
                }

                service.adopt(newConnection)
                newConnection.resume()
                return true
            }
        }
    }
#endif
