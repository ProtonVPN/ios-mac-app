//
//  IPCWGConnection.swift
//  ProtonVPN WireGuard
//
//  Created by Jaroslav on 2021-07-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import os.log

/// App -> Provider IPC
@objc protocol ProviderCommunication {
    func getVersion(_ completionHandler: @escaping (Data?) -> Void)
    func getLogs(_ completionHandler: @escaping (Data?) -> Void)
    func setCredentials(username: String, password: String, completionHandler: @escaping (Bool) -> Void)
}

/// Provider -> App IPC
@objc protocol AppCommunication {
}

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

/// Object to call inside the app that manages responses from XPS service.
class XPCServiceUser {
    
    private let machServiceName: String
    private let log: (String) -> Void
    private var currentConnection: NSXPCConnection?
    
    init(withExtension machServiceName: String, logger: @escaping (String) -> Void) {
        self.machServiceName = machServiceName
        self.log = logger
    }
    
    func getVersion(completionHandler: @escaping (Data?) -> Void) {
        guard let providerProxy = connection.remoteObjectProxyWithErrorHandler({ registerError in
            self.log("Failed to get remote object proxy: \(registerError.localizedDescription)")
            self.currentConnection?.invalidate()
            self.currentConnection = nil
            completionHandler(nil)
        }) as? ProviderCommunication else {
            self.log("Failed to create a remote object proxy for the provider: \(machServiceName)")
            completionHandler(nil)
            return
        }
        
        providerProxy.getVersion(completionHandler)
    }
    
    func getLogs(completionHandler: @escaping (Data?) -> Void) {
        guard let providerProxy = connection.remoteObjectProxyWithErrorHandler({ registerError in
            self.log("Failed to get remote object proxy: \(registerError.localizedDescription)")
            self.currentConnection?.invalidate()
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
            self.log("Failed to get remote object proxy: \(registerError.localizedDescription)")
            self.currentConnection?.invalidate()
            self.currentConnection = nil
            completionHandler(false)
        }) as? ProviderCommunication else {
            self.log("Failed to get remote object proxy: \(machServiceName)")
            completionHandler(false)
            return
        }
        
        providerProxy.setCredentials(username: username, password: password, completionHandler: completionHandler)
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
        
        currentConnection = newConnection
        newConnection.resume()
        
        return newConnection
    }
    
}

extension XPCServiceUser: AppCommunication {
    
}
