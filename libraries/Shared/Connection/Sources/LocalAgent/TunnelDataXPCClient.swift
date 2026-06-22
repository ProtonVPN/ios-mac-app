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

    /// macOS app-side counterpart to the extension's `TunnelDataXPCService`: opens an NSXPC connection to the ProTUN
    /// system extension, fetches the shared tunnel-data `IOSurface`, and attaches it to the `rawChannels` registry.
    public final class TunnelDataXPCClient: @unchecked Sendable {
        @Dependency(\.rawChannels) private var rawChannels

        private let machServiceName: String
        private let log: (String) -> Void

        private let lock = NSLock()
        private var connection: NSXPCConnection?

        public init(machServiceName: String, log: @escaping (String) -> Void = { _ in }) {
            self.machServiceName = machServiceName
            self.log = log
        }

        public func attachRegion() {
            guard let proxy = remoteProxy() else {
                log("Could not obtain ProTUN XPC proxy for \(machServiceName)")
                return
            }
            proxy.fetchTunnelDataSurface { [weak self] surface in
                guard let self else { return }
                guard let surface else {
                    log("Extension returned no tunnel-data surface")
                    return
                }
                rawChannels.attachRegion(IPCNotifications.SharedRegion(ioSurface: surface as IOSurfaceRef))
            }
        }

        // MARK: - Private

        private func remoteProxy() -> TunnelDataXPCProtocol? {
            lock.lock()
            let connection = connection ?? makeConnectionLocked()
            lock.unlock()

            return connection.remoteObjectProxyWithErrorHandler { [weak self] error in
                self?.log("ProTUN XPC proxy error for \(self?.machServiceName ?? "?"): \(String(describing: error))")
                self?.invalidate()
            } as? TunnelDataXPCProtocol
        }

        /// Must be called with `lock` held.
        private func makeConnectionLocked() -> NSXPCConnection {
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
            connection.invalidationHandler = { [weak self] in self?.invalidate() }
            connection.interruptionHandler = { [weak self] in self?.invalidate() }
            connection.resume()
            self.connection = connection
            return connection
        }

        private func invalidate() {
            lock.lock()
            defer { lock.unlock() }
            connection?.invalidate()
            connection = nil
        }
    }
#endif
