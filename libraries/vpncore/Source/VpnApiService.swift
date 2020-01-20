//
//  VpnApiService.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Alamofire
import Foundation

public struct VpnProperties {
    
    public let serverModels: [ServerModel]
    public let vpnCredentials: VpnCredentials?
    public let ip: String?
    
    public init(serverModels: [ServerModel], vpnCredentials: VpnCredentials?, sessionModels: [SessionModel]?, ip: String?, appStateManager: AppStateManager?) {
        self.serverModels = serverModels
        self.vpnCredentials = vpnCredentials
        self.ip = ip
        
        guard let sessionModels = sessionModels else {
            return
        }
        
        let ikeSessions = sessionModels.filter { session -> Bool in
            session.vpnProtocol == .ikev2
        }
        
        let connectedIp = appStateManager?.activeIp
        
        self.serverModels.forEach { server in
            server.ips.forEach { ip in
                ip.hasExistingSession = false
                ikeSessions.forEach { session in
                    if ip.exitIp == session.exitIp {
                        if let connectedIp = connectedIp, connectedIp == ip.exitIp {
                        } else {
                            ip.hasExistingSession = true
                        }
                    }
                }
            }
        }
    }
}

public protocol VpnApiServiceFactory {
    func makeVpnApiService() -> VpnApiService
}

public class VpnApiService {
    
    private let alamofireWrapper: AlamofireWrapper
    
    public var appStateManager: AppStateManager?
    
    public init(alamofireWrapper: AlamofireWrapper) {
        self.alamofireWrapper = alamofireWrapper
    }
    
    public func vpnProperties(lastKnownIp: String?, success: @escaping ((VpnProperties) -> Void), failure: @escaping ((Error) -> Void)) {
        let dispatchGroup = DispatchGroup()
        
        var rCredentials: VpnCredentials?
        var rServerModels: [ServerModel]?
        var rSessionModels: [SessionModel]?
        var rUserIp: String?
        var rError: Error?
        
        let failureClosure: (Error) -> Void = { error in
            rError = error
            dispatchGroup.leave()
        }
        
        let silentFailureClosure: (Error) -> Void = { _ in
            dispatchGroup.leave()
        }
        
        let ipResolvedClosure: (String?) -> Void = { [weak self] ip in
            rUserIp = ip
            
            self?.serverInfo(for: rUserIp,
                success: { serverModels in
                rServerModels = serverModels
                dispatchGroup.leave()
            }, failure: failureClosure)
        }
        
        // Only retrieve IP address when not connected to VPN
        dispatchGroup.enter()
        if appStateManager?.state.isDisconnected ?? true {
            userIp(success: ipResolvedClosure, failure: failureClosure)
        } else {
            ipResolvedClosure(lastKnownIp)
        }
        
        dispatchGroup.enter()
        clientCredentials(success: { credentials in
            rCredentials = credentials
            dispatchGroup.leave()
        }, failure: silentFailureClosure)
        
        dispatchGroup.enter()
        sessions(success: { sessionModels in
            rSessionModels = sessionModels
            dispatchGroup.leave()
        }, failure: silentFailureClosure)
        
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            if let servers = rServerModels {
                success(VpnProperties(serverModels: servers, vpnCredentials: rCredentials, sessionModels: rSessionModels, ip: rUserIp, appStateManager: self?.appStateManager))
            } else if let error = rError {
                failure(error)
            } else {
                failure(ProtonVpnError.vpnProperties)
            }
        }
    }
    
    public func refreshServerInfoIfIpChanged(lastKnownIp: String?, success: @escaping ((VpnProperties) -> Void), failure: @escaping ((Error) -> Void)) {
        let dispatchGroup = DispatchGroup()
        
        var rServerModels: [ServerModel]?
        var rUserIp: String?
        var rError: Error?
        
        let failureClosure: (Error) -> Void = { error in
            rError = error
            dispatchGroup.leave()
        }
        
        let ipResolvedClosure: (String?) -> Void = { [weak self] ip in
            rUserIp = ip
            
            // Only update servers if the user's IP has changed
            guard lastKnownIp != rUserIp else {
                dispatchGroup.leave()
                return
            }
            
            self?.serverInfo(for: rUserIp,
                success: { serverModels in
                rServerModels = serverModels
                dispatchGroup.leave()
            }, failure: failureClosure)
        }
        
        dispatchGroup.enter()
        userIp(success: ipResolvedClosure, failure: failureClosure)
        
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            if let servers = rServerModels {
                success(VpnProperties(serverModels: servers, vpnCredentials: nil, sessionModels: nil, ip: rUserIp, appStateManager: self?.appStateManager))
            } else if let error = rError {
                failure(error)
            } else {
                failure(ProtonVpnError.vpnProperties)
            }
        }
    }
    
    public func clientCredentials(success: @escaping ((VpnCredentials) -> Void), failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { json in
            do {
                let vpnCredential = try VpnCredentials(dic: json)
                success(vpnCredential)
            } catch {
                let error = error as NSError
                if error.code != -1 {
                    PMLog.ET(error.localizedDescription)
                    failure(error)
                } else {
                    PMLog.D("Error occurred during user's VPN credentials parsing", level: .error)
                    let error = ParseError.vpnCredentialsParse
                    PMLog.ET(error.localizedDescription)
                    failure(error)
                }
            }
        }
        
        alamofireWrapper.request(VpnRouter.clientCredentials, success: successWrapper, failure: failure)
    }
    
    public func serverInfoSuccessWrapper(success: @escaping (([ServerModel]) -> Void), failure: @escaping ((Error) -> Void)) -> ((JSONDictionary) -> Void) {
        let successWrapper: (JSONDictionary) -> Void = { response in
            guard let serversJson = response.jsonArray(key: "LogicalServers") else {
                PMLog.D("'Servers' field not present in server info request's response", level: .error)
                let error = ParseError.serverParse
                PMLog.ET(error.localizedDescription)
                failure(error)
                return
            }
            
            var serverModels: [ServerModel] = []
            for json in serversJson {
                do {
                    serverModels.append(try ServerModel(dic: json))
                } catch {
                    PMLog.D("Failed to parse server info for json: \(json)", level: .error)
                    let error = ParseError.serverParse
                    PMLog.ET(error.localizedDescription)
                }
            }
            success(serverModels)
        }
        
        return successWrapper
    }
    
    // The following route is used to retrieve VPN server information, including scores for the best server to connect to depending on a user's proximity to a server and its load. To provide relevant scores even when connected to VPN, we send a truncated version of the user's public IP address. In keeping with our no-logs policy, this partial IP address is not stored on the server and is only used to fulfill this one-off API request.
    public func serverInfo(for ip: String?, success: @escaping (([ServerModel]) -> Void), failure: @escaping ((Error) -> Void)) {
        var shortenedIp: String?
        if let ip = ip {
            shortenedIp = truncatedIp(ip)
        }
        
        let successWrapper = serverInfoSuccessWrapper(success: success, failure: failure)
        alamofireWrapper.request(VpnRouter.logicalServices(ip: shortenedIp), success: successWrapper, failure: failure)
    }
    
    public func userIp(success: @escaping ((String) -> Void), failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { response in
            guard let ip = response.string("IP") else {
                PMLog.D("'IP' field not present in user's ip location response", level: .error)
                let error = ParseError.userIpParse
                PMLog.ET(error.localizedDescription)
                failure(error)
                return
            }
            success(ip)
        }
        
        alamofireWrapper.request(VpnRouter.location, success: successWrapper, failure: failure)
    }
    
    public func sessions(success: @escaping (([SessionModel]) -> Void), failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { response in
            guard let sessionsJson = response.jsonArray(key: "Sessions") else {
                PMLog.D("'Sessions' field not present in user's sessions response", level: .error)
                let error = ParseError.sessionCountParse
                PMLog.ET(error.localizedDescription)
                failure(error)
                return
            }
            
            var sessions = [SessionModel]()
            for json in sessionsJson {
                do {
                    sessions.append(try SessionModel(dic: json))
                } catch {
                    PMLog.D("Failed to parse session info for json: \(json)", level: .error)
                    let error = ParseError.serverParse
                    PMLog.ET(error.localizedDescription)
                }
            }
            
            success(sessions)
        }
        
        alamofireWrapper.request(VpnRouter.sessions, success: successWrapper, failure: failure)
    }
    
    public func loads(success: @escaping ((ContinuousServerPropertiesDictionary) -> Void), failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { response in
            guard let loadsJson = response.jsonArray(key: "LogicalServers") else {
                PMLog.D("'LogicalServers' field not present in loads response", level: .error)
                let error = ParseError.loadsParse
                PMLog.ET(error.localizedDescription)
                failure(error)
                return
            }
            
            var loads = ContinuousServerPropertiesDictionary()
            for json in loadsJson {
                do {
                    let load = try ContinuousServerProperties(dic: json)
                    loads[load.serverId] = load
                } catch {
                    PMLog.D("Failed to parse load info for json: \(json)", level: .error)
                    let error = ParseError.loadsParse
                    PMLog.ET(error.localizedDescription)
                }
            }
            
            success(loads)
        }
        
        alamofireWrapper.request(VpnRouter.loads, success: successWrapper, failure: failure)
    }
    
    // MARK: - Private
    
    private func truncatedIp(_ ip: String) -> String {
        // Remove the last octet
        if let index = ip.lastIndex(of: ".") { // IPv4
            return ip.replacingCharacters(in: index..<ip.endIndex, with: ".0")
        } else if let index = ip.lastIndex(of: ":") { // IPv6
            return ip.replacingCharacters(in: index..<ip.endIndex, with: "::")
        } else {
            return ip
        }
    }
}
