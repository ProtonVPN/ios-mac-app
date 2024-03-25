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

/// IPCClientCommunication.swift is compiled into the ProtonVPN app and is used for
/// communication between the app and NetworkExtensions. Its counterpart,
/// IPCServerCommunication.swift, is compiled into the NetworkExtensions and serves
/// a symmetrical purpose.

import Foundation

/// Object to call inside the app that manages responses from XPC service.
final class XPCServiceUser {
    private let machServiceName: String
    private let log: (String) -> Void

    private var currentConnection: NSXPCConnection? {
        willSet {
            if newValue == nil {
                currentConnection?.invalidate()
            }
        }
    }

    init(withExtension machServiceName: String, logger: @escaping (String) -> Void) {
        self.machServiceName = machServiceName
        self.log = logger
    }

    func getLogs(completionHandler: @escaping (Data?) -> Void) {
        guard let providerProxy = connection.remoteObjectProxyWithErrorHandler({ registerError in
            self.log("Failed to get remote object proxy \(self.machServiceName): \(String(describing: registerError))")
            self.currentConnection = nil
            completionHandler(nil)
        }) as? ProviderCommunication else {
            self.log("Failed to create a remote object proxy for the provider: \(machServiceName)")
            completionHandler(nil)
            return
        }

        providerProxy.getLogs(completionHandler)
    }

    func setCredentials(username: String, password: String, completionHandler: @escaping (Bool) -> Void) {
        guard let providerProxy = connection.remoteObjectProxyWithErrorHandler({ registerError in
            self.log("Failed to get remote object proxy \(self.machServiceName): \(String(describing: registerError))")
            self.currentConnection = nil
            completionHandler(false)
        }) as? ProviderCommunication else {
            self.log("Failed to get remote object proxy: \(machServiceName)")
            completionHandler(false)
            return
        }

        providerProxy.setCredentials(username: username, password: password, completionHandler: completionHandler)
    }

    func setConfigData(_ data: Data, completionHandler: @escaping (Bool) -> Void) {
        guard let providerProxy = connection.remoteObjectProxyWithErrorHandler({ registerError in
            self.log("Failed to get remote object proxy \(self.machServiceName): \(String(describing: registerError))")
            self.currentConnection = nil
            completionHandler(false)
        }) as? ProviderCommunication else {
            self.log("Failed to get remote object proxy: \(machServiceName)")
            completionHandler(false)
            return
        }

        providerProxy.setConfigData(data, completionHandler: completionHandler)
    }

    // MARK: - Private

    private var connection: NSXPCConnection {
        guard currentConnection == nil else {
            return currentConnection!
        }

        let newConnection = NSXPCConnection(machServiceName: machServiceName, options: [])

        // The exported object is the delegate.
        newConnection.exportedInterface = NSXPCInterface(with: AppCommunication.self)
        newConnection.exportedObject = self

        // The remote object is the provider's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: ProviderCommunication.self)

        newConnection.invalidationHandler = { [weak self] in
            guard let self else { return }
            log("XPC invalidated for mach service \(machServiceName)")
        }

        newConnection.interruptionHandler = { [weak self] in
            guard let self else { return }
            log("XPC connection interrupted for mach service \(machServiceName)")
        }

        currentConnection = newConnection
        newConnection.resume()

        return newConnection
    }
}

extension XPCServiceUser: AppCommunication {

}
