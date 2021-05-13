//
//  ConfigurationParser.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 9/5/18.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import SwiftyBeaver
import __TunnelKitCore

private let log = SwiftyBeaver.self

extension OpenVPN {

    /// Provides methods to parse a `Configuration` from an .ovpn configuration file.
    public class ConfigurationParser {

        // XXX: parsing is very optimistic
        
        struct Regex {
            
            // MARK: General
            
            static let cipher = NSRegularExpression("^cipher +[^,\\s]+")
            
            static let dataCiphers = NSRegularExpression("^(data-ciphers|ncp-ciphers) +[^,\\s]+(:[^,\\s]+)*")
            
            static let dataCiphersFallback = NSRegularExpression("^data-ciphers-fallback +[^,\\s]+")
            
            static let auth = NSRegularExpression("^auth +[\\w\\-]+")
            
            static let compLZO = NSRegularExpression("^comp-lzo.*")
            
            static let compress = NSRegularExpression("^compress.*")
            
            static let keyDirection = NSRegularExpression("^key-direction +\\d")
            
            static let ping = NSRegularExpression("^ping +\\d+")
            
            static let pingRestart = NSRegularExpression("^ping-restart +\\d+")
            
            static let renegSec = NSRegularExpression("^reneg-sec +\\d+")
            
            static let blockBegin = NSRegularExpression("^<[\\w\\-]+>")
            
            static let blockEnd = NSRegularExpression("^<\\/[\\w\\-]+>")
            
            // MARK: Client
            
            static let proto = NSRegularExpression("^proto +(udp[46]?|tcp[46]?)")
            
            static let port = NSRegularExpression("^port +\\d+")
            
            static let remote = NSRegularExpression("^remote +[^ ]+( +\\d+)?( +(udp[46]?|tcp[46]?))?")
            
            static let eku = NSRegularExpression("^remote-cert-tls +server")
            
            static let remoteRandom = NSRegularExpression("^remote-random")
            
            static let mtu = NSRegularExpression("^tun-mtu +\\d+")
            
            // MARK: Server
            
            static let authToken = NSRegularExpression("^auth-token +[a-zA-Z0-9/=+]+")
            
            static let peerId = NSRegularExpression("^peer-id +[0-9]+")
            
            // MARK: Routing
            
            static let topology = NSRegularExpression("^topology +(net30|p2p|subnet)")
            
            static let ifconfig = NSRegularExpression("^ifconfig +[\\d\\.]+ [\\d\\.]+")
            
            static let ifconfig6 = NSRegularExpression("^ifconfig-ipv6 +[\\da-fA-F:]+/\\d+ [\\da-fA-F:]+")
            
            static let route = NSRegularExpression("^route +[\\d\\.]+( +[\\d\\.]+){0,2}")
            
            static let route6 = NSRegularExpression("^route-ipv6 +[\\da-fA-F:]+/\\d+( +[\\da-fA-F:]+){0,2}")
            
            static let gateway = NSRegularExpression("^route-gateway +[\\d\\.]+")
            
            static let dns = NSRegularExpression("^dhcp-option +DNS6? +[\\d\\.a-fA-F:]+")
            
            static let domain = NSRegularExpression("^dhcp-option +DOMAIN +[^ ]+")
            
            static let domainSearch = NSRegularExpression("^dhcp-option +DOMAIN-SEARCH +[^ ]+")
            
            static let proxy = NSRegularExpression("^dhcp-option +PROXY_(HTTPS? +[^ ]+ +\\d+|AUTO_CONFIG_URL +[^ ]+)")
            
            static let proxyBypass = NSRegularExpression("^dhcp-option +PROXY_BYPASS +.+")
            
            static let redirectGateway = NSRegularExpression("^redirect-gateway.*")

            // MARK: Unsupported
            
    //        static let fragment = NSRegularExpression("^fragment +\\d+")
            static let fragment = NSRegularExpression("^fragment")
            
            static let connectionProxy = NSRegularExpression("^\\w+-proxy")
            
            static let externalFiles = NSRegularExpression("^(ca|cert|key|tls-auth|tls-crypt) ")
            
            static let connection = NSRegularExpression("^<connection>")
            
            // MARK: Continuation
            
            static let continuation = NSRegularExpression("^push-continuation [12]")
        }
        
        private enum Topology: String {
            case net30
            
            case p2p
            
            case subnet
        }
        
        private enum RedirectGateway: String {
            case def1 // default

            case noIPv4 = "!ipv4"
            
            case ipv6

            case local
            
            case autolocal
            
            case blockLocal = "block-local"

            case bypassDHCP = "bypass-dhcp"
            
            case bypassDNS = "bypass-dns"
        }
        
        /// Result of the parser.
        public struct Result {

            /// Original URL of the configuration file, if parsed from an URL.
            public let url: URL?

            /// The overall parsed `Configuration`.
            public let configuration: Configuration

            /// The lines of the configuration file stripped of any sensitive data. Lines that
            /// the parser does not recognize are discarded in the first place.
            ///
            /// - Seealso: `ConfigurationParser.parsed(...)`
            public let strippedLines: [String]?
            
            /// Holds an optional `ConfigurationError` that didn't block the parser, but it would be worth taking care of.
            public let warning: ConfigurationError?
        }
        
        /**
         Parses an .ovpn file from an URL.
         
         - Parameter url: The URL of the configuration file.
         - Parameter passphrase: The optional passphrase for encrypted data.
         - Parameter returnsStripped: When `true`, stores the stripped file into `Result.strippedLines`. Defaults to `false`.
         - Returns: The `Result` outcome of the parsing.
         - Throws: `ConfigurationError` if the configuration file is wrong or incomplete.
         */
        public static func parsed(fromURL url: URL, passphrase: String? = nil, returnsStripped: Bool = false) throws -> Result {
            let lines = try String(contentsOf: url).trimmedLines()
            return try parsed(fromLines: lines, isClient: true, passphrase: passphrase, originalURL: url, returnsStripped: returnsStripped)
        }

        /**
         Parses a configuration from an array of lines.
         
         - Parameter lines: The array of lines holding the configuration.
         - Parameter isClient: Enables additional checks for client configurations.
         - Parameter passphrase: The optional passphrase for encrypted data.
         - Parameter originalURL: The optional original URL of the configuration file.
         - Parameter returnsStripped: When `true`, stores the stripped file into `Result.strippedLines`. Defaults to `false`.
         - Returns: The `Result` outcome of the parsing.
         - Throws: `ConfigurationError` if the configuration file is wrong or incomplete.
         */
        public static func parsed(fromLines lines: [String], isClient: Bool = false, passphrase: String? = nil, originalURL: URL? = nil, returnsStripped: Bool = false) throws -> Result {
            var optStrippedLines: [String]? = returnsStripped ? [] : nil
            var optWarning: ConfigurationError?
            var unsupportedError: ConfigurationError?
            var currentBlockName: String?
            var currentBlock: [String] = []
            
            var optDataCiphers: [Cipher]?
            var optDataCiphersFallback: Cipher?
            var optCipher: Cipher?
            var optDigest: Digest?
            var optCompressionFraming: CompressionFraming?
            var optCompressionAlgorithm: CompressionAlgorithm?
            var optCA: CryptoContainer?
            var optClientCertificate: CryptoContainer?
            var optClientKey: CryptoContainer?
            var optKeyDirection: StaticKey.Direction?
            var optTLSKeyLines: [Substring]?
            var optTLSStrategy: TLSWrap.Strategy?
            var optKeepAliveSeconds: TimeInterval?
            var optKeepAliveTimeoutSeconds: TimeInterval?
            var optRenegotiateAfterSeconds: TimeInterval?
            //
            var optDefaultProto: SocketType?
            var optDefaultPort: UInt16?
            var optRemotes: [(String, UInt16?, SocketType?)] = [] // address, port, socket
            var optChecksEKU: Bool?
            var optRandomizeEndpoint: Bool?
            var optMTU: Int?
            //
            var optAuthToken: String?
            var optPeerId: UInt32?
            //
            var optTopology: String?
            var optIfconfig4Arguments: [String]?
            var optIfconfig6Arguments: [String]?
            var optGateway4Arguments: [String]?
            var optRoutes4: [(String, String, String?)] = [] // address, netmask, gateway
            var optRoutes6: [(String, UInt8, String?)] = [] // destination, prefix, gateway
            var optDNSServers: [String]?
            var optDomain: String?
            var optSearchDomains: [String]?
            var optHTTPProxy: Proxy?
            var optHTTPSProxy: Proxy?
            var optProxyAutoConfigurationURL: URL?
            var optProxyBypass: [String]?
            var optRedirectGateway: Set<RedirectGateway>?

            log.verbose("Configuration file:")
            for line in lines {
                log.verbose(line)
                
                var isHandled = false
                var strippedLine = line
                defer {
                    if isHandled {
                        optStrippedLines?.append(strippedLine)
                    }
                }
                
                // MARK: Unsupported
                
                // check blocks first
                Regex.connection.enumerateComponents(in: line) { (_) in
                    unsupportedError = ConfigurationError.unsupportedConfiguration(option: "<connection> blocks")
                }
                Regex.fragment.enumerateComponents(in: line) { (_) in
                    unsupportedError = ConfigurationError.unsupportedConfiguration(option: "fragment")
                }
                Regex.connectionProxy.enumerateComponents(in: line) { (_) in
                    unsupportedError = ConfigurationError.unsupportedConfiguration(option: "proxy: \"\(line)\"")
                }
                Regex.externalFiles.enumerateComponents(in: line) { (_) in
                    unsupportedError = ConfigurationError.unsupportedConfiguration(option: "external file: \"\(line)\"")
                }
                if line.contains("mtu") || line.contains("mssfix") {
                    isHandled = true
                }
                
                // MARK: Continuation

                var isContinuation = false
                Regex.continuation.enumerateArguments(in: line) {
                    isContinuation = ($0.first == "2")
                }
                guard !isContinuation else {
                    throw OpenVPNError.continuationPushReply
                }

                // MARK: Inline content
                
                if unsupportedError == nil {
                    if currentBlockName == nil {
                        Regex.blockBegin.enumerateComponents(in: line) {
                            isHandled = true
                            let tag = $0.first!
                            let from = tag.index(after: tag.startIndex)
                            let to = tag.index(before: tag.endIndex)
                            
                            currentBlockName = String(tag[from..<to])
                            currentBlock = []
                        }
                    }
                    Regex.blockEnd.enumerateComponents(in: line) {
                        isHandled = true
                        let tag = $0.first!
                        let from = tag.index(tag.startIndex, offsetBy: 2)
                        let to = tag.index(before: tag.endIndex)
                        
                        let blockName = String(tag[from..<to])
                        guard blockName == currentBlockName else {
                            return
                        }
                        
                        // first is opening tag
                        currentBlock.removeFirst()
                        switch blockName {
                        case "ca":
                            optCA = CryptoContainer(pem: currentBlock.joined(separator: "\n"))
                            
                        case "cert":
                            optClientCertificate = CryptoContainer(pem: currentBlock.joined(separator: "\n"))
                            
                        case "key":
                            ConfigurationParser.normalizeEncryptedPEMBlock(block: &currentBlock)
                            optClientKey = CryptoContainer(pem: currentBlock.joined(separator: "\n"))
                            
                        case "tls-auth":
                            optTLSKeyLines = currentBlock.map { Substring($0) }
                            optTLSStrategy = .auth
                            
                        case "tls-crypt":
                            optTLSKeyLines = currentBlock.map { Substring($0) }
                            optTLSStrategy = .crypt
                            
                        default:
                            break
                        }
                        currentBlockName = nil
                        currentBlock = []
                    }
                }
                if let _ = currentBlockName {
                    currentBlock.append(line)
                    continue
                }
                
                // MARK: General
                
                Regex.cipher.enumerateArguments(in: line) {
                    isHandled = true
                    guard let rawValue = $0.first else {
                        return
                    }
                    optCipher = Cipher(rawValue: rawValue.uppercased())
                }
                Regex.dataCiphers.enumerateArguments(in: line) {
                    isHandled = true
                    guard let rawValue = $0.first else {
                        return
                    }
                    let rawCiphers = rawValue.components(separatedBy: ":")
                    optDataCiphers = []
                    rawCiphers.forEach {
                        guard let cipher = Cipher(rawValue: $0.uppercased()) else {
                            return
                        }
                        optDataCiphers?.append(cipher)
                    }
                }
                Regex.dataCiphersFallback.enumerateArguments(in: line) {
                    isHandled = true
                    guard let rawValue = $0.first else {
                        return
                    }
                    optDataCiphersFallback = Cipher(rawValue: rawValue.uppercased())
                }
                Regex.auth.enumerateArguments(in: line) {
                    isHandled = true
                    guard let rawValue = $0.first else {
                        return
                    }
                    optDigest = Digest(rawValue: rawValue.uppercased())
                    if optDigest == nil {
                        unsupportedError = ConfigurationError.unsupportedConfiguration(option: "auth \(rawValue)")
                    }
                }
                Regex.compLZO.enumerateArguments(in: line) {
                    isHandled = true
                    optCompressionFraming = .compLZO
                    
                    if !LZOIsSupported() {
                        guard let arg = $0.first else {
                            optWarning = optWarning ?? .unsupportedConfiguration(option: line)
                            return
                        }
                        guard arg == "no" else {
                            unsupportedError = .unsupportedConfiguration(option: line)
                            return
                        }
                    } else {
                        let arg = $0.first
                        optCompressionAlgorithm = (arg == "no") ? .disabled : .LZO
                    }
                }
                Regex.compress.enumerateArguments(in: line) {
                    isHandled = true
                    optCompressionFraming = .compress
                    
                    if !LZOIsSupported() {
                        guard $0.isEmpty else {
                            unsupportedError = .unsupportedConfiguration(option: line)
                            return
                        }
                    } else {
                        if let arg = $0.first {
                            optCompressionAlgorithm = (arg == "lzo") ? .LZO : .other
                        } else {
                            optCompressionAlgorithm = .disabled
                        }
                    }
                }
                Regex.keyDirection.enumerateArguments(in: line) {
                    isHandled = true
                    guard let arg = $0.first, let value = Int(arg) else {
                        return
                    }
                    optKeyDirection = StaticKey.Direction(rawValue: value)
                }
                Regex.ping.enumerateArguments(in: line) {
                    isHandled = true
                    guard let arg = $0.first else {
                        return
                    }
                    optKeepAliveSeconds = TimeInterval(arg)
                }
                Regex.pingRestart.enumerateArguments(in: line) {
                    isHandled = true
                    guard let arg = $0.first else {
                        return
                    }
                    optKeepAliveTimeoutSeconds = TimeInterval(arg)
                }
                Regex.renegSec.enumerateArguments(in: line) {
                    isHandled = true
                    guard let arg = $0.first else {
                        return
                    }
                    optRenegotiateAfterSeconds = TimeInterval(arg)
                }
                
                // MARK: Client
                
                Regex.proto.enumerateArguments(in: line) {
                    isHandled = true
                    guard let str = $0.first else {
                        return
                    }
                    optDefaultProto = SocketType(protoString: str)
                    if optDefaultProto == nil {
                        unsupportedError = ConfigurationError.unsupportedConfiguration(option: "proto \(str)")
                    }
                }
                Regex.port.enumerateArguments(in: line) {
                    isHandled = true
                    guard let str = $0.first else {
                        return
                    }
                    optDefaultPort = UInt16(str)
                }
                Regex.remote.enumerateArguments(in: line) {
                    isHandled = true
                    guard let hostname = $0.first else {
                        return
                    }
                    var port: UInt16?
                    var proto: SocketType?
                    var strippedComponents = ["remote", "<hostname>"]
                    if $0.count > 1 {
                        port = UInt16($0[1])
                        strippedComponents.append($0[1])
                    }
                    if $0.count > 2 {
                        proto = SocketType(protoString: $0[2])
                        strippedComponents.append($0[2])
                    }
                    optRemotes.append((hostname, port, proto))
                    
                    // replace private data
                    strippedLine = strippedComponents.joined(separator: " ")
                }
                Regex.eku.enumerateComponents(in: line) { (_) in
                    isHandled = true
                    optChecksEKU = true
                }
                Regex.remoteRandom.enumerateComponents(in: line) { (_) in
                    isHandled = true
                    optRandomizeEndpoint = true
                }
                Regex.mtu.enumerateArguments(in: line) {
                    isHandled = true
                    guard let str = $0.first else {
                        return
                    }
                    optMTU = Int(str)
                }
                
                // MARK: Server
                
                Regex.authToken.enumerateArguments(in: line) {
                    optAuthToken = $0[0]
                }
                Regex.peerId.enumerateArguments(in: line) {
                    optPeerId = UInt32($0[0])
                }
                
                // MARK: Routing
                
                Regex.topology.enumerateArguments(in: line) {
                    optTopology = $0.first
                }
                Regex.ifconfig.enumerateArguments(in: line) {
                    optIfconfig4Arguments = $0
                }
                Regex.ifconfig6.enumerateArguments(in: line) {
                    optIfconfig6Arguments = $0
                }
                Regex.route.enumerateArguments(in: line) {
                    let routeEntryArguments = $0
                    
                    let address = routeEntryArguments[0]
                    let mask = (routeEntryArguments.count > 1) ? routeEntryArguments[1] : "255.255.255.255"
                    var gateway = (routeEntryArguments.count > 2) ? routeEntryArguments[2] : nil // defaultGateway4
                    if gateway == "vpn_gateway" {
                        gateway = nil
                    }
                    optRoutes4.append((address, mask, gateway))
                }
                Regex.route6.enumerateArguments(in: line) {
                    let routeEntryArguments = $0
                    
                    let destinationComponents = routeEntryArguments[0].components(separatedBy: "/")
                    guard destinationComponents.count == 2 else {
                        return
                    }
                    guard let prefix = UInt8(destinationComponents[1]) else {
                        return
                    }
                    
                    let destination = destinationComponents[0]
                    var gateway = (routeEntryArguments.count > 1) ? routeEntryArguments[1] : nil // defaultGateway6
                    if gateway == "vpn_gateway" {
                        gateway = nil
                    }
                    optRoutes6.append((destination, prefix, gateway))
                }
                Regex.gateway.enumerateArguments(in: line) {
                    optGateway4Arguments = $0
                }
                Regex.dns.enumerateArguments(in: line) {
                    guard $0.count == 2 else {
                        return
                    }
                    if optDNSServers == nil {
                        optDNSServers = []
                    }
                    optDNSServers?.append($0[1])
                }
                Regex.domain.enumerateArguments(in: line) {
                    guard $0.count == 2 else {
                        return
                    }
                    optDomain = $0[1]
                }
                Regex.domainSearch.enumerateArguments(in: line) {
                    guard $0.count == 2 else {
                        return
                    }
                    if optSearchDomains == nil {
                        optSearchDomains = []
                    }
                    optSearchDomains?.append($0[1])
                }
                Regex.proxy.enumerateArguments(in: line) {
                    if $0.count == 2 {
                        guard let url = URL(string: $0[1]) else {
                            unsupportedError = ConfigurationError.malformed(option: "dhcp-option PROXY_AUTO_CONFIG_URL has malformed URL")
                            return
                        }
                        optProxyAutoConfigurationURL = url
                        return
                    }

                    guard $0.count == 3, let port = UInt16($0[2]) else {
                        return
                    }
                    switch $0[0] {
                    case "PROXY_HTTPS":
                        optHTTPSProxy = Proxy($0[1], port)
                        
                    case "PROXY_HTTP":
                        optHTTPProxy = Proxy($0[1], port)

                    default:
                        break
                    }
                }
                Regex.proxyBypass.enumerateArguments(in: line) {
                    guard !$0.isEmpty else {
                        return
                    }
                    optProxyBypass = $0
                    optProxyBypass?.removeFirst()
                }
                Regex.redirectGateway.enumerateArguments(in: line) {

                    // redirect IPv4 by default
                    optRedirectGateway = [.def1]

                    for arg in $0 {
                        guard let opt = RedirectGateway(rawValue: arg) else {
                            continue
                        }
                        optRedirectGateway?.insert(opt)
                    }
                }

                //
                
                if let error = unsupportedError {
                    throw error
                }
            }
            
            if isClient {
                guard let _ = optCA else {
                    throw ConfigurationError.missingConfiguration(option: "ca")
                }
                guard optCipher != nil || !(optDataCiphers?.isEmpty ?? false) else {
                    throw ConfigurationError.missingConfiguration(option: "cipher or data-ciphers")
                }
            }
            
            //
            
            var sessionBuilder = ConfigurationBuilder()
            
            // MARK: General
            
            sessionBuilder.cipher = optDataCiphersFallback ?? optCipher
            sessionBuilder.dataCiphers = optDataCiphers
            sessionBuilder.digest = optDigest
            sessionBuilder.compressionFraming = optCompressionFraming
            sessionBuilder.compressionAlgorithm = optCompressionAlgorithm
            sessionBuilder.ca = optCA
            sessionBuilder.clientCertificate = optClientCertificate
            
            if let clientKey = optClientKey, clientKey.isEncrypted {
                guard let passphrase = passphrase else {
                    throw ConfigurationError.encryptionPassphrase
                }
                do {
                    sessionBuilder.clientKey = try clientKey.decrypted(with: passphrase)
                } catch let e {
                    throw ConfigurationError.unableToDecrypt(error: e)
                }
            } else {
                sessionBuilder.clientKey = optClientKey
            }
            
            if let keyLines = optTLSKeyLines, let strategy = optTLSStrategy {
                let optKey: StaticKey?
                switch strategy {
                case .auth:
                    optKey = StaticKey(lines: keyLines, direction: optKeyDirection)
                    
                case .crypt:
                    optKey = StaticKey(lines: keyLines, direction: .client)
                }
                if let key = optKey {
                    sessionBuilder.tlsWrap = TLSWrap(strategy: strategy, key: key)
                }
            }
            
            sessionBuilder.keepAliveInterval = optKeepAliveSeconds
            sessionBuilder.keepAliveTimeout = optKeepAliveTimeoutSeconds
            sessionBuilder.renegotiatesAfter = optRenegotiateAfterSeconds
            
            // MARK: Client
            
            optDefaultProto = optDefaultProto ?? .udp
            optDefaultPort = optDefaultPort ?? 1194
            if !optRemotes.isEmpty {
                sessionBuilder.hostname = optRemotes[0].0
                
                var fullRemotes: [(String, UInt16, SocketType)] = []
                let hostname = optRemotes[0].0
                optRemotes.forEach {
                    guard $0.0 == hostname else {
                        return
                    }
                    guard let port = $0.1 ?? optDefaultPort else {
                        return
                    }
                    guard let socketType = $0.2 ?? optDefaultProto else {
                        return
                    }
                    fullRemotes.append((hostname, port, socketType))
                }
                sessionBuilder.endpointProtocols = fullRemotes.map { EndpointProtocol($0.2, $0.1) }
            } else {
                sessionBuilder.hostname = nil
            }
            
            sessionBuilder.checksEKU = optChecksEKU
            sessionBuilder.randomizeEndpoint = optRandomizeEndpoint
            sessionBuilder.mtu = optMTU
            
            // MARK: Server
            
            sessionBuilder.authToken = optAuthToken
            sessionBuilder.peerId = optPeerId
            
            // MARK: Routing
            
            //
            // excerpts from OpenVPN manpage
            //
            // "--ifconfig l rn":
            //
            // Set  TUN/TAP  adapter parameters.  l is the IP address of the local VPN endpoint.  For TUN devices in point-to-point mode, rn is the IP address of
            // the remote VPN endpoint.  For TAP devices, or TUN devices used with --topology subnet, rn is the subnet mask of the virtual network segment  which
            // is being created or connected to.
            //
            // "--topology mode":
            //
            // Note: Using --topology subnet changes the interpretation of the arguments of --ifconfig to mean "address netmask", no longer "local remote".
            //
            if let ifconfig4Arguments = optIfconfig4Arguments {
                guard ifconfig4Arguments.count == 2 else {
                    throw ConfigurationError.malformed(option: "ifconfig takes 2 arguments")
                }
                
                let address4: String
                let addressMask4: String
                let defaultGateway4: String
                
                let topology = Topology(rawValue: optTopology ?? "") ?? .net30
                switch topology {
                case .subnet:
                    
                    // default gateway required when topology is subnet
                    guard let gateway4Arguments = optGateway4Arguments, gateway4Arguments.count == 1 else {
                        throw ConfigurationError.malformed(option: "route-gateway takes 1 argument")
                    }
                    address4 = ifconfig4Arguments[0]
                    addressMask4 = ifconfig4Arguments[1]
                    defaultGateway4 = gateway4Arguments[0]
                    
                default:
                    address4 = ifconfig4Arguments[0]
                    addressMask4 = "255.255.255.255"
                    defaultGateway4 = ifconfig4Arguments[1]
                }
                let routes4 = optRoutes4.map { IPv4Settings.Route($0.0, $0.1, $0.2 ?? defaultGateway4) }

                sessionBuilder.ipv4 = IPv4Settings(
                    address: address4,
                    addressMask: addressMask4,
                    defaultGateway: defaultGateway4,
                    routes: routes4
                )
            }
            
            if let ifconfig6Arguments = optIfconfig6Arguments {
                guard ifconfig6Arguments.count == 2 else {
                    throw ConfigurationError.malformed(option: "ifconfig-ipv6 takes 2 arguments")
                }
                let address6Components = ifconfig6Arguments[0].components(separatedBy: "/")
                guard address6Components.count == 2 else {
                    throw ConfigurationError.malformed(option: "ifconfig-ipv6 address must have a /prefix")
                }
                guard let addressPrefix6 = UInt8(address6Components[1]) else {
                    throw ConfigurationError.malformed(option: "ifconfig-ipv6 address prefix must be a 8-bit number")
                }
                
                let address6 = address6Components[0]
                let defaultGateway6 = ifconfig6Arguments[1]
                let routes6 = optRoutes6.map { IPv6Settings.Route($0.0, $0.1, $0.2 ?? defaultGateway6) }
                
                sessionBuilder.ipv6 = IPv6Settings(
                    address: address6,
                    addressPrefixLength: addressPrefix6,
                    defaultGateway: defaultGateway6,
                    routes: routes6
                )
            }
            
            // prepend search domains with main domain (if set)
            if let domain = optDomain {
                if optSearchDomains == nil {
                    optSearchDomains = [domain]
                } else {
                    optSearchDomains?.insert(domain, at: 0)
                }
            }

            sessionBuilder.dnsServers = optDNSServers
            sessionBuilder.searchDomains = optSearchDomains
            sessionBuilder.httpProxy = optHTTPProxy
            sessionBuilder.httpsProxy = optHTTPSProxy
            sessionBuilder.proxyAutoConfigurationURL = optProxyAutoConfigurationURL
            sessionBuilder.proxyBypassDomains = optProxyBypass

            if let flags = optRedirectGateway {
                var policies: Set<RoutingPolicy> = []
                for opt in flags {
                    switch opt {
                    case .def1:
                        policies.insert(.IPv4)
                        
                    case .ipv6:
                        policies.insert(.IPv6)
                        
                    case .blockLocal:
                        policies.insert(.blockLocal)

                    default:
                        // TODO: handle [auto]local and block-*
                        continue
                    }
                }
                if flags.contains(.noIPv4) {
                    policies.remove(.IPv4)
                }
                sessionBuilder.routingPolicies = [RoutingPolicy](policies)
            }

            //
            
            return Result(
                url: originalURL,
                configuration: sessionBuilder.build(),
                strippedLines: optStrippedLines,
                warning: optWarning
            )
        }

        private static func normalizeEncryptedPEMBlock(block: inout [String]) {
    //        if block.count >= 1 && block[0].contains("ENCRYPTED") {
    //            return true
    //        }
            
            // XXX: restore blank line after encryption header (easier than tweaking trimmedLines)
            if block.count >= 3 && block[1].contains("Proc-Type") {
                block.insert("", at: 3)
    //            return true
            }
    //        return false
        }
    }
}

private extension String {
    func trimmedLines() -> [String] {
        return components(separatedBy: .newlines).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter {
            !$0.isEmpty
        }
    }
}

private extension SocketType {
    init?(protoString: String) {
        self.init(rawValue: protoString.uppercased())
    }
}
