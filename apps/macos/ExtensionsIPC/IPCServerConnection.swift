//
//  Created on 2022-03-04.
//
//  Copyright (c) 2022 Proton AG
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

/// IPCServerCommunication.swift is compiled into the NetworkExtensions and is used for
/// communication between the NetworkExtensions and the app. Its counterpart,
/// IPCClientCommunication.swift, is compiled into the application and serves
/// a symmetrical purpose.

import Foundation

/// Service part working on Extension side of the connection.
class XPCBaseService: NSObject {

    private let machServiceName: String
    let log: (String) -> Void

    private var currentConnection: NSXPCConnection?
    private var listener: NSXPCListener?

    init(withExtension machServiceName: String, logger: @escaping (String) -> Void) {
        self.machServiceName = machServiceName
        self.log = logger
    }

    func startListener() {
        log("Starting XPC listener for mach service \(machServiceName)")

        let newListener = NSXPCListener(machServiceName: machServiceName)
        newListener.delegate = self
        newListener.resume()
        listener = newListener
    }

}

extension XPCBaseService: ProviderCommunication {

    func getVersion(_ completionHandler: @escaping (Data?) -> Void) {
        log("getVersion: \(ExtensionInfo.current)")
        completionHandler(try? JSONEncoder().encode(ExtensionInfo.current))
    }

    func getLogs(_ completionHandler: @escaping (Data?) -> Void) {
        log("This is just a placeholder! Add `getLogs` in each implementation.")
    }

    func setCredentials(username: String, password: String, completionHandler: @escaping (Bool) -> Void) {
        log("This is just a placeholder! Add `setCredentials` in each implementation.")
    }

}

extension XPCBaseService: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Check the code signature of the remote endpoint to avoid tampering.
        let auditToken = newConnection.auditToken

        do {
            guard try CodeSignatureComparitor.codeSignatureMatches(auditToken: auditToken) else {
                self.log("Refusing XPC connection: code signature does not match")
                return false
            }
        } catch {
            self.log("Refusing XPC connection due to code signing error: \(String(describing: error))")
            return false
        }

        // The exported object is this IPCConnection instance.
        newConnection.exportedInterface = NSXPCInterface(with: ProviderCommunication.self)
        newConnection.exportedObject = self

        // The remote object is the delegate of the app's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: AppCommunication.self)

        newConnection.invalidationHandler = {
            self.log("XPC invalidated for mach service \(self.machServiceName)")
            self.currentConnection = nil
        }

        newConnection.interruptionHandler = {
            self.log("XPC connection interrupted for mach service \(self.machServiceName)")
            self.currentConnection = nil
        }

        if self.currentConnection != nil {
            self.currentConnection?.invalidate()
            self.currentConnection = nil
        }

        currentConnection = newConnection
        newConnection.resume()

        return true
    }
}
