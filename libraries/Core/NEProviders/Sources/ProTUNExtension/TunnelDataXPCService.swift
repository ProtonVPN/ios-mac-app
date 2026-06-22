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
    import LocalAgent
    import LocalAgentIPC
    import XPCAuditToken

    /// Used on macOS to establish a shared memory region between the System Extension and the the app/other extensions
    ///
    /// The sysex runs as root, so it can't share the app group container. Consumers of ``RawChannel``s need to check
    /// in with the mach service on macOS to gain access to channel memory.
    public final class TunnelDataXPCService: NSObject, @unchecked Sendable {
        private let machServiceName: String
        private let log: (String) -> Void

        /// The backing memory for all ``RawChannel``s published by this extension.
        private let surface: IOSurfaceRef?

        private var listener: NSXPCListener?
        private var currentConnection: NSXPCConnection?

        public init(machServiceName: String, log: @escaping (String) -> Void = { _ in }) {
            self.machServiceName = machServiceName
            self.log = log
            self.surface = IPCNotifications.SharedRegion.makeIOSurface(size: MemoryLayout<IPCTunnelData>.size)
            super.init()

            // Immediately attach the raw channel region on startup.
            if let surface {
                @Dependency(\.rawChannels) var rawChannels
                rawChannels.attachRegion(IPCNotifications.SharedRegion(ioSurface: surface))
            } else {
                log("Failed to allocate tunnel-data IOSurface; the macOS app will not receive live tunnel data")
            }
        }

        public func startListener() {
            log("Starting tunnel-data XPC listener for mach service \(machServiceName)")
            let listener = NSXPCListener(machServiceName: machServiceName)
            listener.delegate = self
            listener.resume()
            self.listener = listener
        }
    }

    extension TunnelDataXPCService: TunnelDataXPCProtocol {
        public func fetchTunnelDataSurface(_ reply: @escaping (IOSurface?) -> Void) {
            reply(surface as IOSurface?)
        }
    }

    extension TunnelDataXPCService: NSXPCListenerDelegate {
        public func listener(_: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
            // Check the audit trailer so that we only accept connections from binaries with the same cert chain as us.
            let pid = newConnection.processIdentifier
            do {
                let matches = try CodeSignatureComparator.codeSignatureMatches(auditToken: newConnection.auditToken)
                #if DEBUG
                    // Poke a hole for local development.
                    if !matches {
                        log("Code signature of pid \(pid) does not match. Proceeding anyway for debug.")
                    }
                #else
                    guard matches else {
                        log("Refusing XPC connection with pid \(pid): code signature does not match")
                        return false
                    }
                #endif
            } catch {
                log("Code signing error while verifying pid \(pid): \(String(describing: error))")
                #if !DEBUG
                    return false
                #endif
            }

            let interface = NSXPCInterface(with: TunnelDataXPCProtocol.self)

            // Whitelist `IOSurface` as a reply argument for NSXPC.
            interface.setClasses(
                Set<AnyHashable>([IOSurface.self as AnyHashable]),
                for: #selector(TunnelDataXPCProtocol.fetchTunnelDataSurface(_:)),
                argumentIndex: 0,
                ofReply: true
            )

            newConnection.exportedInterface = interface
            newConnection.exportedObject = self
            newConnection.invalidationHandler = { [weak self] in self?.currentConnection = nil }
            newConnection.interruptionHandler = { [weak self] in self?.currentConnection = nil }

            currentConnection?.invalidate()
            currentConnection = newConnection
            newConnection.resume()
            return true
        }
    }
#endif
