//
//  Created on 30/09/2025 by Adam Viaud.
//
//  Copyright (c) 2025 Proton AG
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

import Logging
import Network
import NetworkExtension
import OSLog

@preconcurrency import VPNAppCore

import Besogne

final class FlowHandlingManager: Sendable {
    enum RouteAction {
        case dontHandle
        case forward(handler: FlowHandler)
    }

    let configuration: PlutoniumProviderConfiguration

    private static let openFlowTimeoutDelay: DispatchTimeInterval = .seconds(2)

    private let queue = DispatchQueue(label: "ch.protonvpn.mac.transparent-proxy.flowHandlingManager", attributes: .concurrent)
    private let monitorQueue = DispatchQueue(label: "ch.protonvpn.mac.transparent-proxy.pathMonitor")

    private let appIDs: Set<String>

    private let activeTCPHandlers: OSAllocatedUnfairLock<Set<TCPFlowHandler>> = .init(initialState: [])
    private let activeUDPHandlers: OSAllocatedUnfairLock<Set<UDPFlowHandler>> = .init(initialState: [])

    private nonisolated(unsafe) var pathMonitor: NWPathMonitor?
    private nonisolated(unsafe) var destInterface: NWInterface? // it will only be modified from a serial queue
    private nonisolated(unsafe) var isPathMonitorRunning: Bool = false // modified from a serial queue as well created within this class

    init(plutoniumConfiguration: PlutoniumProviderConfiguration) {
        self.configuration = plutoniumConfiguration
        self.appIDs = plutoniumConfiguration.appIDs
    }

    func startPathMonitoring() {
        monitorQueue.sync {
            guard !isPathMonitorRunning else {
                return
            }

            pathMonitor = NWPathMonitor()
            pathMonitor?.pathUpdateHandler = { [weak self] path in
                self?.destInterface = path.availableInterfaces.filter(\.isPhysical).first // availableInterfaces is sorted
            }
            pathMonitor?.start(queue: .main)
            isPathMonitorRunning = true
        }
    }

    func stopPathMonitoring() {
        monitorQueue.sync {
            guard isPathMonitorRunning else {
                return
            }

            pathMonitor?.cancel()
            pathMonitor?.pathUpdateHandler = nil
            destInterface = nil
            isPathMonitorRunning = false
        }
    }

    func routeActionForFlow(_ flow: NEAppProxyFlow) -> RouteAction {
        if flow.isDNSFlow {
            return .dontHandle
        }
        guard appIDExists(flow.sourceAppIdentifier) else {
            return .dontHandle
        }
        switch flow {
        case let tcpFlow as NEAppProxyTCPFlow:
            return .forward(handler: TCPFlowHandler(flow: tcpFlow))
        case let udpFlow as NEAppProxyUDPFlow:
            return .forward(handler: UDPFlowHandler(flow: udpFlow))
        default:
            assertionFailure("Unknown handler type (\(flow)), you should define a route for it")
            return .dontHandle
        }
    }

    func registerAndStart(flow: any FlowHandler) {
        switch flow {
        case let tcpFlow as TCPFlowHandler:
            _ = activeTCPHandlers.withLock { $0.insert(tcpFlow) }

            queue.async {
                self.start(tcpFlow: tcpFlow)
            }
        case let udpFlow as UDPFlowHandler:
            _ = activeUDPHandlers.withLock { $0.insert(udpFlow) }

            queue.async {
                self.start(udpFlow: udpFlow)
            }
        default:
            assertionFailure("Unknown handler type (\(flow)), you should handle it")
        }
    }

    private func start(tcpFlow: TCPFlowHandler) {
        let besogne = Besogne(description: "TCPFlowHandler start")
        besogne.apply {
            do {
                let flowId = tcpFlow.id
                let socket = try tcpFlow.setup(destInterface: destInterface)

                Logger.tcp.debug("TCP Socket configured and connected")

                let group = DispatchGroup()
                var openFlowResult: Result<Void, TCPFlowHandlerError> = .success(())

                group.enter()
                tcpFlow.openFlow { result in
                    openFlowResult = result
                    group.leave()
                }

                let groupResult = group.wait(timeout: .now() + Self.openFlowTimeoutDelay)

                switch (groupResult, openFlowResult) {
                case (.success, .success):
                    Logger.provider.debug("Succesfully opened TCPFlowHandler \(flowId)")

                    tcpFlow.start(socket: socket) { [weak self, unowned tcpFlow] result in
                        switch result {
                        case .success:
                            Logger.provider.info("TCPFlowHandler \(flowId) successfully handled")
                        case let .failure(error):
                            Logger.provider.error("Error while handling TCPFlowHandler: \(error)")
                        }
                        _ = self?.activeTCPHandlers.withLock { $0.remove(tcpFlow) }
                    }
                case let (.success, .failure(error)):
                    Logger.tcp.error("Opening flow failed with error: \(error)")
                case (.timedOut, _):
                    Logger.tcp.error("Opening flow timed out")
                }
            } catch {
                Logger.tcp.error("Error setuping socket: \(error)")
            }
        }
    }

    private func start(udpFlow: UDPFlowHandler) {
        let besogne = Besogne(description: "UDPFlowHandler start")
        besogne.apply {
            do {
                let flowId = udpFlow.id
                let socket = try udpFlow.setup(destInterface: destInterface)

                Logger.udp.debug("UDP Socket configured and connected")

                let localFlowEndpoint = try UDPFlowHandler.localEndpoint(with: socket)

                let group = DispatchGroup()
                var openFlowResult: Result<Void, UDPFlowHandlerError> = .success(())

                group.enter()
                udpFlow.openFlow(localFlowEndpoint: localFlowEndpoint) { result in
                    openFlowResult = result
                    group.leave()
                }

                let groupResult = group.wait(timeout: .now() + Self.openFlowTimeoutDelay)

                switch (groupResult, openFlowResult) {
                case (.success, .success):
                    Logger.provider.debug("Succesfully opened UDPFlowHandler \(flowId)")

                    udpFlow.start(socket: socket) { [weak self, unowned udpFlow] result in
                        switch result {
                        case .success:
                            Logger.provider.info("UDPFlowHandler \(flowId) successfully handled")
                        case let .failure(error):
                            Logger.provider.log(level: .error, "Error while handling UDPFlowHandler: \(error)")
                        }
                        _ = self?.activeUDPHandlers.withLock { $0.remove(udpFlow) }
                    }
                case let (.success, .failure(error)):
                    Logger.udp.error("Opening flow failed with error: \(error)")
                case (.timedOut, _):
                    Logger.udp.error("Opening flow timed out")
                }
            } catch {
                Logger.udp.error("Error setting up socket: \(error)")
            }
        }
    }

    func stopAll() {
        activeUDPHandlers.withLock { handlers in
            for handler in handlers {
                handler.stop()
            }
            handlers.removeAll()
        }
        activeTCPHandlers.withLock { handlers in
            for handler in handlers {
                handler.stop()
            }
            handlers.removeAll()
        }

        Logger.provider.info("Stopped all flows")
    }
}

private extension FlowHandlingManager {
    func appIDExists(_ appID: String?) -> Bool {
        guard let appID else { return false }
        return appIDs.contains(appID)
    }
}

private extension NWInterface {
    var isPhysical: Bool {
        switch type {
        case .wifi, .wiredEthernet, .cellular:
            return true
        case .loopback, .other:
            return false
        @unknown default:
            return false
        }
    }
}
