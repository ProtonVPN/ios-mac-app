//
//  NetworkHelper.swift
//  ProtonVPN - Created on 27.06.19.
//
//  MIT License
//
//  Orignal work Copyright (c) 2018 Erik Berglund
//  Modified work Copyright (c) 2019 Proton Technologies AG
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

class NetworkHelper: NSObject {
    
    private let xpcListener: NSXPCListener
    
    private var connections = [NSXPCConnection]()
    
    override init() {
        xpcListener = NSXPCListener(machServiceName: NetworkHelperConstants.machServiceName)
        super.init()
        
        xpcListener.delegate = self
    }
    
    func run() {
        xpcListener.resume()
        
        RunLoop.current.run()
    }
    
    private func validateCodeSigning(connection: NSXPCConnection) -> Bool {
        do {
            return try CodeSignatureComparitor.codeSignatureMatches(pid: connection.processIdentifier)
        } catch {
            #if DEBUG
            print("Code signing check failed with error: \(error)")
            #endif
            return false
        }
    }
    
    private func connection() -> NSXPCConnection? {
        return self.connections.last
    }
    
    private func remoteObject() -> AppProtocol? {
        return connection()?.remoteObjectProxy as? AppProtocol
    }
}

extension NetworkHelper: NetworkHelperProtocol {
    
    func getVersion(completion: @escaping (String) -> ()) {
        completion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")
    }
    
    func unload(completion: @escaping (NSNumber) -> ()) {
        CommandLineToolRunner.unloadFromLaunchd(completion: completion)
    }
    
    func anyFirewallEnabled(completion: @escaping (NSNumber) -> Void) {
        guard let logger = remoteObject() else {
            completion(-1)
            return
        }
        
        CommandLineToolRunner.checkIfAnyFirewallIsEnabled(logger: logger, completion: completion)
    }
    
    func firewallEnabled(forServer address: String, completion: @escaping (NSNumber) -> ()) {
        guard let logger = remoteObject() else {
            completion(-1)
            return
        }
        
        CommandLineToolRunner.checkIfFirewallIsEnabled(forServer: address, logger: logger, completion: completion)
    }
    
    func enableFirewall(with file: URL, completion: @escaping (NSNumber) -> ()) {
        CommandLineToolRunner.enableFirewall(with: file, completion: completion)
    }
    
    func disableFirewall(completion: @escaping (NSNumber) -> ()) {
        CommandLineToolRunner.disableFirewall(completion: completion)
    }
}

extension NetworkHelper: NSXPCListenerDelegate {
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard self.validateCodeSigning(connection: connection) else {
            return false
        }
        
        // Set the protocol that the calling application conforms to
        connection.remoteObjectInterface = NSXPCInterface(with: AppProtocol.self)
        
        // Set the protocol that the helper conforms to
        connection.exportedInterface = NSXPCInterface(with: NetworkHelperProtocol.self)
        connection.exportedObject = self
        
        // Set the invalidation handler to remove this connection when its work is completed
        connection.invalidationHandler = {
            if let connectionIndex = self.connections.firstIndex(of: connection) {
                self.connections.remove(at: connectionIndex)
            }
        }
        
        self.connections.append(connection)
        connection.resume()
        
        return true
    }
}
