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

import ProtonCore_Networking

public protocol VpnApiServiceFactory {
    func makeVpnApiService() -> VpnApiService
}

public class VpnApiService {
    public var appStateManager: AppStateManager?
    private let networking: Networking
    
    public init(networking: Networking) {
        self.networking = networking
    }
    
    // swiftlint:disable function_body_length cyclomatic_complexity
    public func vpnProperties(lastKnownIp: String?, completion: @escaping (Result<VpnProperties, Error>) -> Void) {
        let dispatchGroup = DispatchGroup()
        
        var rCredentials: VpnCredentials?
        var rServerModels: [ServerModel]?
        var rStreamingServices: VPNStreamingResponse?
        var rUserIp: String?
        var rClientConfig: ClientConfig?
        var rError: Error?

        let failureClosure: ErrorCallback = { error in
            rError = error
            dispatchGroup.leave()
        }
        
        let silentFailureClosure: ErrorCallback = { _ in
            dispatchGroup.leave()
        }
        
        let ipResolvedClosure = { [weak self] (ip: String?) in
            rUserIp = ip
            
            self?.serverInfo(for: rUserIp) { result in
                switch result {
                case let .success(serverModels):
                    rServerModels = serverModels
                    dispatchGroup.leave()
                case let .failure(error):
                    failureClosure(error)
                }
            }
        }
        
        // Only retrieve IP address when not connected to VPN
        dispatchGroup.enter()
        if appStateManager?.state.isDisconnected ?? true {
            // Just use last known IP if getting new one failed
            userIp { result in
                switch result {
                case let .success(ip):
                    ipResolvedClosure(ip)
                case .failure:
                    ipResolvedClosure(lastKnownIp)
                }
            }
        } else {
            ipResolvedClosure(lastKnownIp)
        }
        
        dispatchGroup.enter()
        clientCredentials { result in
            switch result {
            case let .success(credentials):
                rCredentials = credentials
                dispatchGroup.leave()
            case let .failure(error):
                silentFailureClosure(error)
            }
        }
        
        dispatchGroup.enter()
        virtualServices { result in
            switch result {
            case let .success(response):
                rStreamingServices = response
                dispatchGroup.leave()
            case let .failure(error):
                silentFailureClosure(error)
            }
        }
        
        dispatchGroup.enter()
        clientConfig { result in
            switch result {
            case let .success(config):
                rClientConfig = config
                dispatchGroup.leave()
            case let .failure(error):
                failureClosure(error)
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            if let servers = rServerModels {
                completion(.success(VpnProperties(serverModels: servers, vpnCredentials: rCredentials, ip: rUserIp, clientConfig: rClientConfig, streamingResponse: rStreamingServices)))
            } else if let error = rError {
                completion(.failure(error))
            } else {
                completion(.failure(ProtonVpnError.vpnProperties))
            }
        }
    }
    
    public func refreshServerInfoIfIpChanged(lastKnownIp: String?, completion: @escaping (Result<VpnProperties, Error>) -> Void) {
        let dispatchGroup = DispatchGroup()
        
        var rServerModels: [ServerModel]?
        var rStreamingServices: VPNStreamingResponse?
        var rUserIp: String?
        var rClientConfig: ClientConfig?
        var rError: Error?

        let failureClosure: ErrorCallback = { error in
            rError = error
            dispatchGroup.leave()
        }
        
        let ipResolvedClosure = { [weak self] (ip: String) in
            rUserIp = ip
            
            // Only update servers if the user's IP has changed
            guard lastKnownIp != rUserIp else {
                dispatchGroup.leave()
                return
            }

            self?.serverInfo(for: rUserIp) { result in
                switch result {
                case let .success(serverModels):
                    rServerModels = serverModels
                    dispatchGroup.leave()
                case let .failure(error):
                    failureClosure(error)
                }
            }
            
            dispatchGroup.enter()
            self?.virtualServices { result in
                switch result {
                case let .success(response):
                    rStreamingServices = response
                    dispatchGroup.leave()
                case let .failure(error):
                    failureClosure(error)
                }
            }
        }

        dispatchGroup.enter()
        userIp { result in
            switch result {
            case let .success(ip):
                ipResolvedClosure(ip)
            case let.failure(error):
                failureClosure(error)
            }
        }
        
        dispatchGroup.enter()
        clientConfig { result in
            switch result {
            case let .success(config):
                rClientConfig = config
                dispatchGroup.leave()
            case let .failure(error):
                failureClosure(error)
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            if let servers = rServerModels {
                completion(.success(VpnProperties(serverModels: servers, vpnCredentials: nil, ip: rUserIp, clientConfig: rClientConfig, streamingResponse: rStreamingServices)))
            } else if let error = rError {
                completion(.failure(error))
            } else {
                completion(.failure(ProtonVpnError.vpnProperties))
            }
        }
    }
    
    // swiftlint:enable function_body_length

    public func clientCredentials(comletion: @escaping (Result<VpnCredentials, Error>) -> Void) {
        networking.request(VPNClientCredentialsRequest()) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(json):
                do {
                    let vpnCredential = try VpnCredentials(dic: json)
                    comletion(.success(vpnCredential))
                } catch {
                    let error = error as NSError
                    if error.code != -1 {
                        PMLog.ET(error.localizedDescription)
                        comletion(.failure(error))
                    } else {
                        PMLog.D("Error occurred during user's VPN credentials parsing", level: .error)
                        let error = ParseError.vpnCredentialsParse
                        PMLog.ET(error.localizedDescription)
                        comletion(.failure(error))
                    }
                }
            case let .failure(error):
                comletion(.failure(error))
            }
        }
    }
    
    // The following route is used to retrieve VPN server information, including scores for the best server to connect to depending on a user's proximity to a server and its load. To provide relevant scores even when connected to VPN, we send a truncated version of the user's public IP address. In keeping with our no-logs policy, this partial IP address is not stored on the server and is only used to fulfill this one-off API request.
    public func serverInfo(for ip: String?, completion: @escaping (Result<[ServerModel], Error>) -> Void) {
        var shortenedIp: String?
        if let ip = ip {
            shortenedIp = truncatedIp(ip)
        }

        networking.request(VPNLogicalServicesRequest(shortenedIp)) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(json):
                guard let serversJson = json.jsonArray(key: "LogicalServers") else {
                    PMLog.D("'Servers' field not present in server info request's response", level: .error)
                    let error = ParseError.serverParse
                    PMLog.ET(error.localizedDescription)
                    completion(.failure(error))
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
                completion(.success(serverModels))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    public func serverState(serverId id: String, completion: @escaping (Result<VpnServerState, Error>) -> Void) {
        networking.request(VPNServerRequest(id)) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(response):
                guard let json = response.jsonDictionary(key: "Server"), let serverState = try? VpnServerState(dictionary: json)  else {
                    let error = ParseError.serverParse
                    PMLog.D("'Server' field not present in server info request's response", level: .error)
                    PMLog.ET(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                completion(.success(serverState))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    public func userIp(completion: @escaping (Result<String, Error>) -> Void) {
        networking.request(VPNLocationRequest()) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(response):
                guard let ip = response.string("IP") else {
                    PMLog.D("'IP' field not present in user's ip location response", level: .error)
                    let error = ParseError.userIpParse
                    PMLog.ET(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                completion(.success(ip))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    public func sessionsCount(completion: @escaping (Result<Int, Error>) -> Void) {
        networking.request(VPNSessionsCountRequest()) { (result: Result<SessionsResponse, Error>) in
            switch result {
            case let .success(response):
                completion(.success(response.sessionCount))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    public func loads(lastKnownIp: String?, completion: @escaping (Result<ContinuousServerPropertiesDictionary, Error>) -> Void) {
        var shortenedIp: String?
        if let ip = lastKnownIp {
            shortenedIp = truncatedIp(ip)
        }
        networking.request(VPNLoadsRequest(shortenedIp)) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(response):
                guard let loadsJson = response.jsonArray(key: "LogicalServers") else {
                    PMLog.D("'LogicalServers' field not present in loads response", level: .error)
                    let error = ParseError.loadsParse
                    PMLog.ET(error.localizedDescription)
                    completion(.failure(error))
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

                completion(.success(loads))
            case let .failure(error):
                completion(.failure(error))
            }

        }
    }
    
    public func clientConfig(completion: @escaping (Result<ClientConfig, Error>) -> Void) {
        networking.request(VPNClientConfigRequest()) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(response):
                do {
                    let data = try JSONSerialization.data(withJSONObject: response as Any, options: [])
                    let decoder = JSONDecoder()
                    // this strategy is decapitalizing first letter of response's labels to get appropriate name
                    decoder.keyDecodingStrategy = .decapitaliseFirstLetter
                    let clientConfigResponse = try decoder.decode(ClientConfigResponse.self, from: data)
                    completion(.success(clientConfigResponse.clientConfig))

                } catch {
                    PMLog.D("Failed to parse load info for json: \(response)", level: .error)
                    let error = ParseError.loadsParse
                    PMLog.ET(error.localizedDescription)
                    completion(.failure(error))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    public func virtualServices(completion: @escaping (Result<VPNStreamingResponse, Error>) -> Void) {
        networking.request(VPNStreamingRequest(), completion: completion)
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
