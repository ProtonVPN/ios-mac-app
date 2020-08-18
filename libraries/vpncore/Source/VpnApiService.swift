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

public typealias OpenVpnConfigCallback = GenericCallback<OpenVpnConfig>
public typealias SessionModelsCallback = GenericCallback<[SessionModel]>
public typealias ServerModelsCallback = GenericCallback<[ServerModel]>
public typealias VpnPropertiesCallback = GenericCallback<VpnProperties>
public typealias VpnServerStateCallback = GenericCallback<VpnServerState>
public typealias VpnCredentialsCallback = GenericCallback<VpnCredentials>
public typealias OptionalStringCallback = GenericCallback<String?>
public typealias ContinuousServerPropertiesCallback = GenericCallback<ContinuousServerPropertiesDictionary>

public protocol VpnApiServiceFactory {
    func makeVpnApiService() -> VpnApiService
}

public class VpnApiService {
    
    private let alamofireWrapper: AlamofireWrapper
    
    public var appStateManager: AppStateManager?
    
    public init(alamofireWrapper: AlamofireWrapper) {
        self.alamofireWrapper = alamofireWrapper
    }
    
    // swiftlint:disable function_body_length
    public func vpnProperties(lastKnownIp: String?, success: @escaping VpnPropertiesCallback, failure: @escaping ErrorCallback) {
        let dispatchGroup = DispatchGroup()
        
        var rCredentials: VpnCredentials?
        var rServerModels: [ServerModel]?
        var rUserIp: String?
        var rOpenVpnConfig: OpenVpnConfig?
        var rError: Error?
        
        let failureClosure: ErrorCallback = { error in
            rError = error
            dispatchGroup.leave()
        }
        
        let silentFailureClosure: ErrorCallback = { _ in
            dispatchGroup.leave()
        }
        
        let ipResolvedClosure: OptionalStringCallback = { [weak self] ip in
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
            // Just use last known IP if getting new one failed
            userIp(success: ipResolvedClosure, failure: { _ in
                ipResolvedClosure(lastKnownIp)
            })
        } else {
            ipResolvedClosure(lastKnownIp)
        }
        
        dispatchGroup.enter()
        clientCredentials(success: { credentials in
            rCredentials = credentials
            dispatchGroup.leave()
        }, failure: silentFailureClosure)
                
        dispatchGroup.enter()
        clientConfig(success: { openVpnConfig in
            rOpenVpnConfig = openVpnConfig
            dispatchGroup.leave()
        }, failure: failureClosure)
        
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            if let servers = rServerModels, let openVpnConfig = rOpenVpnConfig != nil ? rOpenVpnConfig : OpenVpnConfig.defaultConfig {
                success(VpnProperties(serverModels: servers, vpnCredentials: rCredentials, ip: rUserIp, openVpnConfig: openVpnConfig, appStateManager: self?.appStateManager))
            } else if let error = rError {
                failure(error)
            } else {
                failure(ProtonVpnError.vpnProperties)
            }
        }
    }
    // swiftlint:enable function_body_length
    
    public func refreshServerInfoIfIpChanged(lastKnownIp: String?, success: @escaping VpnPropertiesCallback, failure: @escaping ErrorCallback) {
        let dispatchGroup = DispatchGroup()
        
        var rServerModels: [ServerModel]?
        var rUserIp: String?
        var rOpenVpnConfig: OpenVpnConfig?
        var rError: Error?
        
        let failureClosure: ErrorCallback = { error in
            rError = error
            dispatchGroup.leave()
        }
        
        let ipResolvedClosure: OptionalStringCallback = { [weak self] ip in
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
        
        dispatchGroup.enter()
        clientConfig(success: { openVpnConfig in
            rOpenVpnConfig = openVpnConfig
            dispatchGroup.leave()
        }, failure: failureClosure)
        
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            if let servers = rServerModels, let openVpnConfig = rOpenVpnConfig {
                success(VpnProperties(serverModels: servers, vpnCredentials: nil, ip: rUserIp, openVpnConfig: openVpnConfig, appStateManager: self?.appStateManager))
            } else if let error = rError {
                failure(error)
            } else {
                failure(ProtonVpnError.vpnProperties)
            }
        }
    }
    
    public func clientCredentials(success: @escaping VpnCredentialsCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { json in
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
        
        alamofireWrapper.request(VPNClientCredentialsRequest(), success: successWrapper, failure: failure)
    }
    
    public func serverInfoSuccessWrapper(success: @escaping ServerModelsCallback, failure: @escaping ErrorCallback) -> JSONCallback {
        let successWrapper: JSONCallback = { response in
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
    public func serverInfo(for ip: String?, success: @escaping ServerModelsCallback, failure: @escaping ErrorCallback) {
        var shortenedIp: String?
        if let ip = ip {
            shortenedIp = truncatedIp(ip)
        }
        
        let successWrapper = serverInfoSuccessWrapper(success: success, failure: failure)
        alamofireWrapper.request(VPNLogicalServicesRequest(shortenedIp), success: successWrapper, failure: failure)
    }
    
    public func serverState(serverId id: String, success: @escaping VpnServerStateCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { response in
            guard let json = response.jsonDictionary(key: "Server"), let serverState = try? VpnServerState(dictionary: json)  else {
                let error = ParseError.serverParse
                PMLog.D("'Server' field not present in server info request's response", level: .error)
                PMLog.ET(error.localizedDescription)
                failure(error)
                return
            }
            success(serverState)
        }
        alamofireWrapper.request(VPNServerRequest(id), success: successWrapper, failure: failure)
    }
    
    public func userIp(success: @escaping StringCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { response in
            guard let ip = response.string("IP") else {
                PMLog.D("'IP' field not present in user's ip location response", level: .error)
                let error = ParseError.userIpParse
                PMLog.ET(error.localizedDescription)
                failure(error)
                return
            }
            success(ip)
        }
        
        alamofireWrapper.request(VPNLocationRequest(), success: successWrapper, failure: failure)
    }
    
    public func sessions(success: @escaping SessionModelsCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { response in
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
        
        alamofireWrapper.request(VPNSessionsRequest(), success: successWrapper, failure: failure)
    }
    
    public func loads(lastKnownIp: String?, success: @escaping ContinuousServerPropertiesCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { response in
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
        var shortenedIp: String?
        if let ip = lastKnownIp {
            shortenedIp = truncatedIp(ip)
        }
        alamofireWrapper.request(VPNLoadsRequest(shortenedIp), success: successWrapper, failure: failure)
    }
    
    public func clientConfig(success: @escaping OpenVpnConfigCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { response in
            guard let openVpnConfigJson = response.jsonDictionary(key: "OpenVPNConfig") else {
                PMLog.D("'OpenVPNConfig' field not present in clientconfig response", level: .error)
                let error = ParseError.clientConfigParse
                PMLog.ET(error.localizedDescription)
                failure(error)
                return
            }
            
            do {
                let openVpnConfig = try OpenVpnConfig(dic: openVpnConfigJson)
                success(openVpnConfig)
            } catch {
                PMLog.D("Failed to parse load info for json: \(openVpnConfigJson)", level: .error)
                let error = ParseError.loadsParse
                PMLog.ET(error.localizedDescription)
            }
        }
        
        alamofireWrapper.request(VPNClientConfigRequest(), success: successWrapper, failure: failure)
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
