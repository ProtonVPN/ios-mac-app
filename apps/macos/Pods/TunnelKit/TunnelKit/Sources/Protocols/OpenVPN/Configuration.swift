//
//  Configuration.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 8/23/18.
//  Copyright (c) 2020 Davide De Rosa. All rights reserved.
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
//  This file incorporates work covered by the following copyright and
//  permission notice:
//
//      Copyright (c) 2018-Present Private Internet Access
//
//      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//      The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation

extension OpenVPN {
    
    /// A pair of credentials for authentication.
    public struct Credentials: Codable, Equatable {

        /// The username.
        public let username: String
        
        /// The password.
        public let password: String
        
        /// :nodoc
        public init(_ username: String, _ password: String) {
            self.username = username
            self.password = password
        }
        
        // MARK: Equatable

        /// :nodoc:
        public static func ==(lhs: Credentials, rhs: Credentials) -> Bool {
            return (lhs.username == rhs.username) && (lhs.password == rhs.password)
        }
    }

    /// Encryption algorithm.
    public enum Cipher: String, Codable, CustomStringConvertible {
        
        // WARNING: must match OpenSSL algorithm names
        
        /// AES encryption with 128-bit key size and CBC.
        case aes128cbc = "AES-128-CBC"
        
        /// AES encryption with 192-bit key size and CBC.
        case aes192cbc = "AES-192-CBC"
        
        /// AES encryption with 256-bit key size and CBC.
        case aes256cbc = "AES-256-CBC"
        
        /// AES encryption with 128-bit key size and GCM.
        case aes128gcm = "AES-128-GCM"
        
        /// AES encryption with 192-bit key size and GCM.
        case aes192gcm = "AES-192-GCM"
        
        /// AES encryption with 256-bit key size and GCM.
        case aes256gcm = "AES-256-GCM"
        
        /// Returns the key size for this cipher.
        public var keySize: Int {
            switch self {
            case .aes128cbc, .aes128gcm:
                return 128
                
            case .aes192cbc, .aes192gcm:
                return 192
                
            case .aes256cbc, .aes256gcm:
                return 256
            }
        }
        
        /// Digest should be ignored when this is `true`.
        public var embedsDigest: Bool {
            return rawValue.hasSuffix("-GCM")
        }
        
        /// Returns a generic name for this cipher.
        public var genericName: String {
            return rawValue.hasSuffix("-GCM") ? "AES-GCM" : "AES-CBC"
        }
        
        /// :nodoc:
        public var description: String {
            return rawValue
        }
    }
    
    /// Message digest algorithm.
    public enum Digest: String, Codable, CustomStringConvertible {
        
        // WARNING: must match OpenSSL algorithm names
        
        /// SHA1 message digest.
        case sha1 = "SHA1"
        
        /// SHA224 message digest.
        case sha224 = "SHA224"

        /// SHA256 message digest.
        case sha256 = "SHA256"

        /// SHA256 message digest.
        case sha384 = "SHA384"

        /// SHA256 message digest.
        case sha512 = "SHA512"
        
        /// Returns a generic name for this digest.
        public var genericName: String {
            return "HMAC"
        }
        
        /// :nodoc:
        public var description: String {
            return "\(genericName)-\(rawValue)"
        }
    }
    
    /// Routing policy.
    public enum RoutingPolicy: String, Codable {

        /// All IPv4 traffic goes through the VPN.
        case IPv4

        /// All IPv6 traffic goes through the VPN.
        case IPv6
        
        /// Block LAN while connected.
        case blockLocal
    }
    
    /// :nodoc:
    private struct Fallback {
        static let cipher: Cipher = .aes128cbc
        
        static let digest: Digest = .sha1
        
        static let compressionFraming: CompressionFraming = .disabled
    }
    
    /// The way to create a `Configuration` object for a `OpenVPNSession`.
    public struct ConfigurationBuilder {

        // MARK: General
        
        /// The cipher algorithm for data encryption.
        public var cipher: Cipher?
        
        /// The digest algorithm for HMAC.
        public var digest: Digest?
        
        /// Compression framing, disabled by default.
        public var compressionFraming: CompressionFraming?
        
        /// Compression algorithm, disabled by default.
        public var compressionAlgorithm: CompressionAlgorithm?
        
        /// The CA for TLS negotiation (PEM format).
        public var ca: CryptoContainer?
        
        /// The optional client certificate for TLS negotiation (PEM format).
        public var clientCertificate: CryptoContainer?
        
        /// The private key for the certificate in `clientCertificate` (PEM format).
        public var clientKey: CryptoContainer?
        
        /// The optional TLS wrapping.
        public var tlsWrap: TLSWrap?
        
        /// If set, overrides TLS security level (0 = lowest).
        public var tlsSecurityLevel: Int?
        
        /// Sends periodical keep-alive packets if set.
        public var keepAliveInterval: TimeInterval?
        
        /// Disconnects after no keep-alive packets are received within timeout interval if set.
        public var keepAliveTimeout: TimeInterval?
        
        /// The number of seconds after which a renegotiation should be initiated. If `nil`, the client will never initiate a renegotiation.
        public var renegotiatesAfter: TimeInterval?
        
        // MARK: Client
        
        /// The server hostname (picked from first remote).
        public var hostname: String?
        
        /// The list of server endpoints.
        public var endpointProtocols: [EndpointProtocol]?
        
        /// If true, checks EKU of server certificate.
        public var checksEKU: Bool?
        
        /// If true, checks if hostname (sanHost) is present in certificates SAN.
        public var checksSANHost: Bool?
        
        /// The server hostname used for checking certificate SAN.
        public var sanHost: String?
        
        /// Picks endpoint from `remotes` randomly.
        public var randomizeEndpoint: Bool?
        
        /// Server is patched for the PIA VPN provider.
        public var usesPIAPatches: Bool?
        
        // MARK: Server
        
        /// The auth-token returned by the server.
        public var authToken: String?
        
        /// The peer-id returned by the server.
        public var peerId: UInt32?
        
        // MARK: Routing
        
        /// The settings for IPv4. `OpenVPNSession` only evaluates this server-side.
        public var ipv4: IPv4Settings?
        
        /// The settings for IPv6. `OpenVPNSession` only evaluates this server-side.
        public var ipv6: IPv6Settings?
        
        /// The DNS servers.
        public var dnsServers: [String]?
        
        /// The search domain.
        @available(*, deprecated, message: "Use searchDomains instead")
        public var searchDomain: String? {
            didSet {
                guard let searchDomain = searchDomain else {
                    searchDomains = nil
                    return
                }
                searchDomains = [searchDomain]
            }
        }

        /// The search domains. The first one is interpreted as the main domain name.
        public var searchDomains: [String]?

        /// The Proxy Auto-Configuration (PAC) url.
        public var proxyAutoConfigurationURL: URL?
        
        /// The HTTP proxy.
        public var httpProxy: Proxy?

        /// The HTTPS proxy.
        public var httpsProxy: Proxy?
        
        /// The list of domains not passing through the proxy.
        public var proxyBypassDomains: [String]?
        
        /// Policies for redirecting traffic through the VPN gateway.
        public var routingPolicies: [RoutingPolicy]?
        
        /// :nodoc:
        public init() {
        }
        
        /**
         Builds a `Configuration` object.
         
         - Returns: A `Configuration` object with this builder.
         */
        public func build() -> Configuration {
            return Configuration(
                cipher: cipher,
                digest: digest,
                compressionFraming: compressionFraming,
                compressionAlgorithm: compressionAlgorithm,
                ca: ca,
                clientCertificate: clientCertificate,
                clientKey: clientKey,
                tlsWrap: tlsWrap,
                tlsSecurityLevel: tlsSecurityLevel,
                keepAliveInterval: keepAliveInterval,
                keepAliveTimeout: keepAliveTimeout,
                renegotiatesAfter: renegotiatesAfter,
                hostname: hostname,
                endpointProtocols: endpointProtocols,
                checksEKU: checksEKU,
                checksSANHost: checksSANHost,
                sanHost: sanHost,
                randomizeEndpoint: randomizeEndpoint,
                usesPIAPatches: usesPIAPatches,
                authToken: authToken,
                peerId: peerId,
                ipv4: ipv4,
                ipv6: ipv6,
                dnsServers: dnsServers,
                searchDomains: searchDomains,
                httpProxy: httpProxy,
                httpsProxy: httpsProxy,
                proxyAutoConfigurationURL: proxyAutoConfigurationURL,
                proxyBypassDomains: proxyBypassDomains,
                routingPolicies: routingPolicies
            )
        }

        // MARK: Shortcuts
        
        /// :nodoc:
        public var fallbackCipher: Cipher {
            return cipher ?? Fallback.cipher
        }
        
        /// :nodoc:
        public var fallbackDigest: Digest {
            return digest ?? Fallback.digest
        }
        
        /// :nodoc:
        public var fallbackCompressionFraming: CompressionFraming {
            return compressionFraming ?? Fallback.compressionFraming
        }
    }
    
    /// The immutable configuration for `OpenVPNSession`.
    public struct Configuration: Codable {

        /// - Seealso: `ConfigurationBuilder.cipher`
        public let cipher: Cipher?
        
        /// - Seealso: `ConfigurationBuilder.digest`
        public let digest: Digest?
        
        /// - Seealso: `ConfigurationBuilder.compressionFraming`
        public let compressionFraming: CompressionFraming?
        
        /// - Seealso: `ConfigurationBuilder.compressionAlgorithm`
        public let compressionAlgorithm: CompressionAlgorithm?
        
        /// - Seealso: `ConfigurationBuilder.ca`
        public let ca: CryptoContainer?
        
        /// - Seealso: `ConfigurationBuilder.clientCertificate`
        public let clientCertificate: CryptoContainer?
        
        /// - Seealso: `ConfigurationBuilder.clientKey`
        public let clientKey: CryptoContainer?
        
        /// - Seealso: `ConfigurationBuilder.tlsWrap`
        public let tlsWrap: TLSWrap?

        /// - Seealso: `ConfigurationBuilder.tlsSecurityLevel`
        public let tlsSecurityLevel: Int?

        /// - Seealso: `ConfigurationBuilder.keepAliveInterval`
        public let keepAliveInterval: TimeInterval?
        
        /// - Seealso: `ConfigurationBuilder.keepAliveTimeout`
        public let keepAliveTimeout: TimeInterval?

        /// - Seealso: `ConfigurationBuilder.renegotiatesAfter`
        public let renegotiatesAfter: TimeInterval?

        /// - Seealso: `ConfigurationBuilder.hostname`
        public let hostname: String?
        
        /// - Seealso: `ConfigurationBuilder.endpointProtocols`
        public let endpointProtocols: [EndpointProtocol]?

        /// - Seealso: `ConfigurationBuilder.checksEKU`
        public let checksEKU: Bool?
        
        /// - Seealso: `ConfigurationBuilder.checksSANHost`
        public let checksSANHost: Bool?
        
        /// - Seealso: `ConfigurationBuilder.sanHost`
        public let sanHost: String?
        
        /// - Seealso: `ConfigurationBuilder.randomizeEndpoint`
        public let randomizeEndpoint: Bool?
        
        /// - Seealso: `ConfigurationBuilder.usesPIAPatches`
        public let usesPIAPatches: Bool?
        
        /// - Seealso: `ConfigurationBuilder.authToken`
        public let authToken: String?
        
        /// - Seealso: `ConfigurationBuilder.peerId`
        public let peerId: UInt32?
        
        /// - Seealso: `ConfigurationBuilder.ipv4`
        public let ipv4: IPv4Settings?

        /// - Seealso: `ConfigurationBuilder.ipv6`
        public let ipv6: IPv6Settings?

        /// - Seealso: `ConfigurationBuilder.dnsServers`
        public let dnsServers: [String]?
        
        /// - Seealso: `ConfigurationBuilder.searchDomains`
        public let searchDomains: [String]?

        /// - Seealso: `ConfigurationBuilder.httpProxy`
        public let httpProxy: Proxy?

        /// - Seealso: `ConfigurationBuilder.httpsProxy`
        public let httpsProxy: Proxy?
        
        /// - Seealso: `ConfigurationBuilder.proxyAutoConfigurationURL`
        public let proxyAutoConfigurationURL: URL?

        /// - Seealso: `ConfigurationBuilder.proxyBypassDomains`
        public let proxyBypassDomains: [String]?
        
        /// - Seealso: `ConfigurationBuilder.routingPolicies`
        public let routingPolicies: [RoutingPolicy]?
        
        // MARK: Shortcuts
        
        /// :nodoc:
        public var fallbackCipher: Cipher {
            return cipher ?? Fallback.cipher
        }

        /// :nodoc:
        public var fallbackDigest: Digest {
            return digest ?? Fallback.digest
        }

        /// :nodoc:
        public var fallbackCompressionFraming: CompressionFraming {
            return compressionFraming ?? Fallback.compressionFraming
        }
    }
}

// MARK: Modification

extension OpenVPN.Configuration {
    
    /**
     Returns a `ConfigurationBuilder` to use this configuration as a starting point for a new one.
     
     - Returns: An editable `ConfigurationBuilder` initialized with this configuration.
     */
    public func builder() -> OpenVPN.ConfigurationBuilder {
        var builder = OpenVPN.ConfigurationBuilder()
        builder.cipher = cipher
        builder.digest = digest
        builder.compressionFraming = compressionFraming
        builder.compressionAlgorithm = compressionAlgorithm
        builder.ca = ca
        builder.clientCertificate = clientCertificate
        builder.clientKey = clientKey
        builder.tlsWrap = tlsWrap
        builder.tlsSecurityLevel = tlsSecurityLevel
        builder.keepAliveInterval = keepAliveInterval
        builder.keepAliveTimeout = keepAliveTimeout
        builder.renegotiatesAfter = renegotiatesAfter
        builder.hostname = hostname
        builder.endpointProtocols = endpointProtocols
        builder.checksEKU = checksEKU
        builder.checksSANHost = checksSANHost
        builder.sanHost = sanHost
        builder.randomizeEndpoint = randomizeEndpoint
        builder.usesPIAPatches = usesPIAPatches
        builder.authToken = authToken
        builder.peerId = peerId
        builder.ipv4 = ipv4
        builder.ipv6 = ipv6
        builder.dnsServers = dnsServers
        builder.searchDomains = searchDomains
        builder.httpProxy = httpProxy
        builder.httpsProxy = httpsProxy
        builder.proxyAutoConfigurationURL = proxyAutoConfigurationURL
        builder.proxyBypassDomains = proxyBypassDomains
        builder.routingPolicies = routingPolicies
        return builder
    }
}
