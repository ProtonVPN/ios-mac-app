//
//  PacketTunnelProvider.swift
//  ProtonVPN - Created on 04/12/2020.
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

import Foundation
import NetworkExtension
import os
import WireGuardKit
import PMLogger
import NEHelper

class PacketTunnelProvider: NEPacketTunnelProvider {
    override init() {
        super.init()
    }

    deinit {
        wg_log(.info, message: "PacketTunnelProvider deinited")
    }

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { logLevel, message in
            wg_log(.info, message: message)
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) { // swiftlint:disable:this cyclomatic_complexity function_body_length
        let activationAttemptId = options?["activationAttemptId"] as? String
        let errorNotifier = ErrorNotifier(activationAttemptId: activationAttemptId)

        setupLogging()
        wg_log(.info, message: "Starting tunnel from the " + (activationAttemptId == nil ? "OS directly, rather than the app" : "app"))

        guard let tunnelProviderProtocol = self.protocolConfiguration as? NETunnelProviderProtocol else {
            errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            wg_log(.info, message: "Error in guard 1: \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
            return
        }
        
        var socket: String = "udp"
        if let socketTypeInput = tunnelProviderProtocol.providerConfiguration?["wg-protocol"] as? String {
            switch socketTypeInput {
            case "tcp": socket = "tcp"
            case "tls": socket = "tls"
            default: socket = "udp"
            }
        }
        
        guard let tunnelConfiguration = tunnelProviderProtocol.asTunnelConfiguration() else {
            errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            wg_log(.info, message: "Error in guard 2: \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
            return
        }

        // Start the tunnel
        adapter.start(tunnelConfiguration: tunnelConfiguration, socketType: socket) { adapterError in
            guard let adapterError = adapterError else {
                let interfaceName = self.adapter.interfaceName ?? "unknown"
                wg_log(.info, message: "Tunnel interface is \(interfaceName)")

                completionHandler(nil)
                                
                return
            }

            switch adapterError {
            case .cannotLocateTunnelFileDescriptor:
                wg_log(.error, staticMessage: "Starting tunnel failed: could not determine file descriptor")
                errorNotifier.notify(PacketTunnelProviderError.couldNotDetermineFileDescriptor)
                completionHandler(PacketTunnelProviderError.couldNotDetermineFileDescriptor)

            case .dnsResolution(let dnsErrors):
                let hostnamesWithDnsResolutionFailure = dnsErrors.map { $0.address }
                    .joined(separator: ", ")
                wg_log(.error, message: "DNS resolution failed for the following hostnames: \(hostnamesWithDnsResolutionFailure)")
                errorNotifier.notify(PacketTunnelProviderError.dnsResolutionFailure)
                completionHandler(PacketTunnelProviderError.dnsResolutionFailure)

            case .setNetworkSettings(let error):
                wg_log(.error, message: "Starting tunnel failed with setTunnelNetworkSettings returning \(error.localizedDescription)")
                errorNotifier.notify(PacketTunnelProviderError.couldNotSetNetworkSettings)
                completionHandler(PacketTunnelProviderError.couldNotSetNetworkSettings)

            case .startWireGuardBackend(let errorCode):
                wg_log(.error, message: "Starting tunnel failed with wgTurnOn returning \(errorCode)")
                errorNotifier.notify(PacketTunnelProviderError.couldNotStartBackend)
                completionHandler(PacketTunnelProviderError.couldNotStartBackend)

            case .invalidState:
                wg_log(.error, message: "Starting tunnel failed with invalidState")
                // Must never happen
                fatalError()
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        wg_log(.info, message: "Stopping tunnel. Reason: \(reason)")

        adapter.stop { error in
            ErrorNotifier.removeLastErrorFile()

            if let error = error {
                wg_log(.error, message: "Failed to stop WireGuard adapter: \(error.localizedDescription)")
            }
            completionHandler()

            #if os(macOS)
            // HACK: This is a filthy hack to work around Apple bug 32073323 (dup'd by us as 47526107).
            // Remove it when they finally fix this upstream and the fix has been rolled out to
            // sufficient quantities of users.
            exit(0)
            #endif
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        wg_log(.info, message: "Handle App Message size: \(messageData.count)")
        
        if let completionHandler = completionHandler, messageData.count == 1 && messageData[0] == 0 {
            adapter.getRuntimeConfiguration { settings in
                var data: Data?
                if let settings = settings {
                    data = settings.data(using: .utf8)!
                }
                completionHandler(data)
            }
        } else {
            completionHandler?(nil)
        }
    }
    
    private func setupLogging() {
        Logger.configureGlobal(tagged: "PROTON-WG", withFilePath: FileManager.logFileURL?.path)
    }
    
}

extension WireGuardLogLevel {
    var osLogLevel: OSLogType {
        switch self {
        case .verbose:
            return .debug
        case .error:
            return .error
        }
    }
}
