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
import VPNShared

public protocol VpnApiServiceFactory {
    func makeVpnApiService() -> VpnApiService
}

extension Container: VpnApiServiceFactory {
    public func makeVpnApiService() -> VpnApiService {
        return VpnApiService(networking: makeNetworking(), vpnKeychain: makeVpnKeychain())
    }
}

public class VpnApiService {
    private let networking: Networking
    private let vpnKeychain: VpnKeychainProtocol
    
    public init(networking: Networking, vpnKeychain: VpnKeychainProtocol) {
        self.networking = networking
        self.vpnKeychain = vpnKeychain
    }
    
    // swiftlint:disable function_body_length cyclomatic_complexity
    public func vpnProperties(isDisconnected: Bool, lastKnownLocation: UserLocation?, completion: @escaping (Result<VpnProperties, Error>) -> Void) {
        let dispatchGroup = DispatchGroup()
        
        var rCredentials: VpnCredentials?
        var rServerModels: [ServerModel]?
        var rStreamingServices: VPNStreamingResponse?
        var rLocation: UserLocation?
        var rClientConfig: ClientConfig?
        var rError: Error?

        let failureClosure: ErrorCallback = { error in
            rError = error
            dispatchGroup.leave()
        }
        
        let silentFailureClosure: ErrorCallback = { _ in
            dispatchGroup.leave()
        }
        
        let ipResolvedClosure = { [unowned self] (location: UserLocation?) in
            rLocation = location

            var shortenedIp: String?
            if let ip = location?.ip {
                shortenedIp = truncatedIp(ip)
            }
            
            serverInfo(for: shortenedIp) { result in
                switch result {
                case let .success(serverModels):
                    rServerModels = serverModels
                    dispatchGroup.leave() // leave: A
                case let .failure(error):
                    failureClosure(error) // leave: A
                }
            }

            clientConfig(for: shortenedIp) { result in
                switch result {
                case let .success(config):
                    rClientConfig = config
                    dispatchGroup.leave() // leave: B
                case let .failure(error):
                    failureClosure(error) // leave: B
                }
            }
        }
        
        // Only retrieve IP address when not connected to VPN

        dispatchGroup.enter() // enter: A
        dispatchGroup.enter() // enter: B
        if isDisconnected {
            // Just use last known IP if getting new one failed
            userLocation { result in
                switch result {
                case let .success(location):
                    ipResolvedClosure(location)
                case .failure:
                    ipResolvedClosure(lastKnownLocation)
                }
            }
        } else {
            ipResolvedClosure(lastKnownLocation)
        }

        dispatchGroup.enter() // enter: C
        clientCredentials { result in
            switch result {
            case let .success(credentials):
                rCredentials = credentials
                dispatchGroup.leave() // leave: C
            case let .failure(error):
                silentFailureClosure(error) // leave: C
            }
        }
        
        dispatchGroup.enter() // enter: D
        virtualServices { result in
            switch result {
            case let .success(response):
                rStreamingServices = response
                dispatchGroup.leave() // leave: D
            case let .failure(error):
                silentFailureClosure(error) // leave: D
            }
        }

        dispatchGroup.notify(queue: DispatchQueue.main) {
            if let servers = rServerModels {
                completion(.success(VpnProperties(serverModels: servers, vpnCredentials: rCredentials, location: rLocation, clientConfig: rClientConfig, streamingResponse: rStreamingServices)))
            } else if let error = rError {
                completion(.failure(error))
            } else {
                completion(.failure(ProtonVpnError.vpnProperties))
            }
        }
    }

    /// If the user IP has changed since the last connection, refresh the server information. This is a subset of what
    /// is returned from the `vpnProperties` method in the `VpnProperties` object, so just return an anonymous tuple.
    public func refreshServerInfoIfIpChanged(lastKnownIp: String?, // swiftlint:disable:next large_tuple
                                             completion: @escaping (Result<(serverModels: [ServerModel],
                                                                            location: UserLocation?,
                                                                            streamingServices: VPNStreamingResponse?), Error>) -> Void) {
        let dispatchGroup = DispatchGroup()
        
        var rServerModels: [ServerModel]?
        var rStreamingServices: VPNStreamingResponse?
        var rLocation: UserLocation?
        var rError: Error?

        let failureClosure: ErrorCallback = { error in
            rError = error
            dispatchGroup.leave()
        }
        
        let ipResolvedClosure = { [weak self] (location: UserLocation) in
            rLocation = location
            
            // Only update servers if the user's IP has changed
            guard lastKnownIp != rLocation?.ip else {
                dispatchGroup.leave()
                return
            }

            self?.serverInfo(for: rLocation?.ip) { result in
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
        userLocation { result in
            switch result {
            case let .success(location):
                ipResolvedClosure(location)
            case let.failure(error):
                failureClosure(error)
            }
        }

        dispatchGroup.notify(queue: DispatchQueue.main) {
            if let servers = rServerModels {
                completion(.success((servers, rLocation, rStreamingServices)))
            } else if let error = rError {
                completion(.failure(error))
            } else {
                completion(.failure(ProtonVpnError.vpnProperties))
            }
        }
    }
    
    // swiftlint:enable function_body_length

    public func clientCredentials(completion: @escaping (Result<VpnCredentials, Error>) -> Void) {
        networking.request(VPNClientCredentialsRequest()) { (result: Result<VPNShared.JSONDictionary, Error>) in
            switch result {
            case let .success(json):
                do {
                    let vpnCredential = try VpnCredentials(dic: json)
                    completion(.success(vpnCredential))
                } catch {
                    let error = error as NSError
                    if error.code != -1 {
                        log.error("clientCredentials error", category: .api, event: .response, metadata: ["error": "\(error)"])
                        completion(.failure(error))
                    } else {
                        log.error("Error occurred during user's VPN credentials parsing", category: .api, event: .response, metadata: ["error": "\(error)"])
                        let error = ParseError.vpnCredentialsParse
                        completion(.failure(error))
                    }
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    // The following route is used to retrieve VPN server information, including scores for the best server to connect to depending on a user's proximity to a server and its load. To provide relevant scores even when connected to VPN, we send a truncated version of the user's public IP address. In keeping with our no-logs policy, this partial IP address is not stored on the server and is only used to fulfill this one-off API request.
    public func serverInfo(for shortenedIp: String?, completion: @escaping (Result<[ServerModel], Error>) -> Void) {
        networking.request(VPNLogicalServicesRequest(shortenedIp)) { (result: Result<VPNShared.JSONDictionary, Error>) in
            switch result {
            case let .success(json):
                guard let serversJson = json.jsonArray(key: "LogicalServers") else {
                    log.error("'Servers' field not present in server info request's response", category: .api, event: .response)
                    let error = ParseError.serverParse
                    completion(.failure(error))
                    return
                }

                var serverModels: [ServerModel] = []
                for json in serversJson {
                    do {
                        serverModels.append(try ServerModel(dic: json))
                    } catch {
                        log.error("Failed to parse server info for json", category: .api, event: .response, metadata: ["error": "\(error)", "json": "\(json)"])
                    }
                }
                completion(.success(serverModels))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    public func serverState(serverId id: String, completion: @escaping (Result<VpnServerState, Error>) -> Void) {
        networking.request(VPNServerRequest(id)) { (result: Result<VPNShared.JSONDictionary, Error>) in
            switch result {
            case let .success(response):
                guard let json = response.jsonDictionary(key: "Server"), let serverState = try? VpnServerState(dictionary: json)  else {
                    let error = ParseError.serverParse
                    log.error("'Server' field not present in server info request's response", category: .api, event: .response, metadata: ["error": "\(error)"])
                    completion(.failure(error))
                    return
                }
                completion(.success(serverState))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    public func userLocation(completion: @escaping (Result<UserLocation, Error>) -> Void) {
        networking.request(VPNLocationRequest()) { (result: Result<VPNShared.JSONDictionary, Error>) in
            switch result {
            case let .success(response):
                guard let userLocation = try? UserLocation(dic: response) else {
                    let error = ParseError.userIpParse
                    log.error("'IP' field not present in user's ip location response", category: .api, event: .response, metadata: ["error": "\(error)"])
                    completion(.failure(error))
                    return
                }
                completion(.success(userLocation))
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
        networking.request(VPNLoadsRequest(shortenedIp)) { (result: Result<VPNShared.JSONDictionary, Error>) in
            switch result {
            case let .success(response):
                guard let loadsJson = response.jsonArray(key: "LogicalServers") else {
                    let error = ParseError.loadsParse
                    log.error("'LogicalServers' field not present in loads response", category: .api, event: .response, metadata: ["error": "\(error)"])
                    completion(.failure(error))
                    return
                }

                var loads = ContinuousServerPropertiesDictionary()
                for json in loadsJson {
                    do {
                        let load = try ContinuousServerProperties(dic: json)
                        loads[load.serverId] = load
                    } catch {
                        log.error("Failed to parse load info for json", category: .api, event: .response, metadata: ["error": "\(error)", "json": "\(json)"])
                    }
                }

                completion(.success(loads))
            case let .failure(error):
                completion(.failure(error))
            }

        }
    }
    
    public func clientConfig(for shortenedIp: String?, completion: @escaping (Result<ClientConfig, Error>) -> Void) {
        let request = VPNClientConfigRequest(isAuth: vpnKeychain.userIsLoggedIn,
                                             ip: shortenedIp)

        networking.request(request) { (result: Result<VPNShared.JSONDictionary, Error>) in
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
                    log.error("Failed to parse load info for json", category: .api, event: .response, metadata: ["error": "\(error)", "json": "\(response)"])
                    let error = ParseError.loadsParse
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
