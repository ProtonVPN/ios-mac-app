// The Swift Programming Language
// https://docs.swift.org/swift-book

import NetworkExtension
import WireGuardKit
import WireGuardLogging

open class WireGuardPacketTunnelProvider: NEPacketTunnelProvider {
    deinit {
        wg_log(.info, message: "PacketTunnelProvider deinited")
    }

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { logLevel, message in
            wg_log(.info, message: message)
        }
    }()

    open override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        setupLogging()
        completionHandler(nil)
    }

    open override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }

    open override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(messageData)
    }

    open override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }

    open override func wake() {
        // Add code here to wake up.
    }
}

private extension WireGuardPacketTunnelProvider {
    func setupLogging() {
        Logger.configureGlobal(tagged: "PROTON-WG", withFilePath: FileManager.logFileURL?.path)
    }
}
