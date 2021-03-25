//
//  OpenVpnProtocolFactory.swift
//  ProtonVPN - Created on 30.07.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
import NetworkExtension
import TunnelKit

public class OpenVpnProtocolFactory: VpnProtocolFactory {
    
    private static let certificateAuthority = OpenVPN.CryptoContainer(pem: """
-----BEGIN CERTIFICATE-----
MIIFozCCA4ugAwIBAgIBATANBgkqhkiG9w0BAQ0FADBAMQswCQYDVQQGEwJDSDEV
MBMGA1UEChMMUHJvdG9uVlBOIEFHMRowGAYDVQQDExFQcm90b25WUE4gUm9vdCBD
QTAeFw0xNzAyMTUxNDM4MDBaFw0yNzAyMTUxNDM4MDBaMEAxCzAJBgNVBAYTAkNI
MRUwEwYDVQQKEwxQcm90b25WUE4gQUcxGjAYBgNVBAMTEVByb3RvblZQTiBSb290
IENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAt+BsSsZg7+AuqTq7
vDbPzfygtl9f8fLJqO4amsyOXlI7pquL5IsEZhpWyJIIvYybqS4s1/T7BbvHPLVE
wlrq8A5DBIXcfuXrBbKoYkmpICGc2u1KYVGOZ9A+PH9z4Tr6OXFfXRnsbZToie8t
2Xjv/dZDdUDAqeW89I/mXg3k5x08m2nfGCQDm4gCanN1r5MT7ge56z0MkY3FFGCO
qRwspIEUzu1ZqGSTkG1eQiOYIrdOF5cc7n2APyvBIcfvp/W3cpTOEmEBJ7/14RnX
nHo0fcx61Inx/6ZxzKkW8BMdGGQF3tF6u2M0FjVN0lLH9S0ul1TgoOS56yEJ34hr
JSRTqHuar3t/xdCbKFZjyXFZFNsXVvgJu34CNLrHHTGJj9jiUfFnxWQYMo9UNUd4
a3PPG1HnbG7LAjlvj5JlJ5aqO5gshdnqb9uIQeR2CdzcCJgklwRGCyDT1pm7eoiv
WV19YBd81vKulLzgPavu3kRRe83yl29It2hwQ9FMs5w6ZV/X6ciTKo3etkX9nBD9
ZzJPsGQsBUy7CzO1jK4W01+u3ItmQS+1s4xtcFxdFY8o/q1zoqBlxpe5MQIWN6Qa
lryiET74gMHE/S5WrPlsq/gehxsdgc6GDUXG4dk8vn6OUMa6wb5wRO3VXGEc67IY
m4mDFTYiPvLaFOxtndlUWuCruKcCAwEAAaOBpzCBpDAMBgNVHRMEBTADAQH/MB0G
A1UdDgQWBBSDkIaYhLVZTwyLNTetNB2qV0gkVDBoBgNVHSMEYTBfgBSDkIaYhLVZ
TwyLNTetNB2qV0gkVKFEpEIwQDELMAkGA1UEBhMCQ0gxFTATBgNVBAoTDFByb3Rv
blZQTiBBRzEaMBgGA1UEAxMRUHJvdG9uVlBOIFJvb3QgQ0GCAQEwCwYDVR0PBAQD
AgEGMA0GCSqGSIb3DQEBDQUAA4ICAQCYr7LpvnfZXBCxVIVc2ea1fjxQ6vkTj0zM
htFs3qfeXpMRf+g1NAh4vv1UIwLsczilMt87SjpJ25pZPyS3O+/VlI9ceZMvtGXd
MGfXhTDp//zRoL1cbzSHee9tQlmEm1tKFxB0wfWd/inGRjZxpJCTQh8oc7CTziHZ
ufS+Jkfpc4Rasr31fl7mHhJahF1j/ka/OOWmFbiHBNjzmNWPQInJm+0ygFqij5qs
51OEvubR8yh5Mdq4TNuWhFuTxpqoJ87VKaSOx/Aefca44Etwcj4gHb7LThidw/ky
zysZiWjyrbfX/31RX7QanKiMk2RDtgZaWi/lMfsl5O+6E2lJ1vo4xv9pW8225B5X
eAeXHCfjV/vrrCFqeCprNF6a3Tn/LX6VNy3jbeC+167QagBOaoDA01XPOx7Odhsb
Gd7cJ5VkgyycZgLnT9zrChgwjx59JQosFEG1DsaAgHfpEl/N3YPJh68N7fwN41Cj
zsk39v6iZdfuet/sP7oiP5/gLmA/CIPNhdIYxaojbLjFPkftVjVPn49RqwqzJJPR
N8BOyb94yhQ7KO4F3IcLT/y/dsWitY0ZH4lCnAVV/v2YjWAWS3OWyC8BFx/Jmc3W
DK/yPwECUcPgHIeXiRjHnJt0Zcm23O2Q3RphpU+1SO3XixsXpOVOYP6rJIXW9bMZ
A1gTTlpi7A==
-----END CERTIFICATE-----
""")
    
    private static let tlsKey = OpenVPN.StaticKey(lines: """
-----BEGIN OpenVPN Static key V1-----
6acef03f62675b4b1bbd03e53b187727
423cea742242106cb2916a8a4c829756
3d22c7e5cef430b1103c6f66eb1fc5b3
75a672f158e2e2e936c3faa48b035a6d
e17beaac23b5f03b10b868d53d03521d
8ba115059da777a60cbfd7b2c9c57472
78a15b8f6e68a3ef7fd583ec9f398c8b
d4735dab40cbd1e3c62a822e97489186
c30a0b48c7c38ea32ceb056d3fa5a710
e10ccc7a0ddb363b08c3d2777a3395e1
0c0b6080f56309192ab5aacd4b45f55d
a61fc77af39bd81a19218a79762c3386
2df55785075f37d8c71dc8a42097ee43
344739a0dd48d03025b0450cf1fb5e8c
aeb893d9a96d1f15519bb3c4dcb40ee3
16672ea16c012664f8a9f11255518deb
-----END OpenVPN Static key V1-----
""".split(separator: "\n"),
                                                  direction: .client)!
    
    private let bundleId: String
    private let appGroup: String
    private let propertiesManager: PropertiesManagerProtocol
    private var vpnManager: NETunnelProviderManager?
    
    private lazy var emptyTunnelConfiguration: OpenVPNTunnelProvider.Configuration = {
        let emptyOpenVpnConfiguration = OpenVPN.ConfigurationBuilder().build()
        var emptyTunnelBuilder = OpenVPNTunnelProvider.ConfigurationBuilder(sessionConfiguration: emptyOpenVpnConfiguration)
        emptyTunnelBuilder.shouldDebug = true // can always be true, since this object is only used to read/delete logs, not create any
        
        return emptyTunnelBuilder.build()
    }()
    
    public init(bundleId: String, appGroup: String, propertiesManager: PropertiesManagerProtocol) {
        self.bundleId = bundleId
        self.appGroup = appGroup
        self.propertiesManager = propertiesManager
    }
    
    public func create(_ configuration: VpnManagerConfiguration) throws -> NEVPNProtocol {
        let openVpnConfig = openVpnConfiguration(for: configuration)
        let generator = tunnelProviderGenerator(for: openVpnConfig)
        let credentials = OpenVPN.Credentials(configuration.username, configuration.password)
        #if !os(macOS) // On mac sysex sets the password itself. Doing it here, prevents it from connecting.
        let keychain = TunnelKit.Keychain(group: appGroup)
        try? keychain.set(password: credentials.password, for: credentials.username, context: bundleId)
        #endif
        let neProtocol = try generator.generatedTunnelProtocol(withBundleIdentifier: bundleId, appGroup: appGroup, context: bundleId, username: credentials.username)
        return neProtocol
    }
    
    public func vpnProviderManager(for requirement: VpnProviderManagerRequirement, completion: @escaping (NEVPNManager?, Error?) -> Void) {
        if requirement == .status, let vpnManager = vpnManager {
            completion(vpnManager, nil)
        } else {
            loadManager(completion: completion)
        }
    }
    
    public func connectionStarted(configuration: VpnManagerConfiguration, completion: @escaping () -> Void) {
        #if !os(macOS)
        // Nothing to do on iOS
        completion()
        
        #else
        
        let credentials = OpenVPN.Credentials(configuration.username, configuration.password)
        
        guard let vpnManager = vpnManager,
              let session = vpnManager.connection as? NETunnelProviderSession,
              let message = try? JSONEncoder().encode(credentials) else {
            completion()
            return
        }
        do {
            try session.sendProviderMessage(message, responseHandler: { result in
                completion()
            })
        } catch {
            completion()
        }
        
        #endif
    }
    
    public func logs(completion: @escaping (String?) -> Void) {
        logData { [appGroup, emptyTunnelConfiguration] (data) in
            guard let data = data, let log = String(data: data, encoding: .utf8) else {
                let log = emptyTunnelConfiguration.existingLog(in: appGroup)
                completion(log)
                return
            }
            completion(log)
        }
    }
    
    public func logFile(completion: @escaping (URL?) -> Void) {
        guard let logUrl = emptyTunnelConfiguration.urlForLog(in: appGroup) else {
            completion(nil)
            return
        }
        
        completion(logUrl)
    }
    
    // MARK: - Private stuff
    private func loadManager(completion: @escaping (NEVPNManager?, Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            guard let `self` = self else {
                completion(nil, ProtonVpnError.vpnManagerUnavailable)
                return
            }
            if let error = error {
                completion(nil, error)
                return
            }
            guard let managers = managers else {
                completion(nil, ProtonVpnError.vpnManagerUnavailable)
                return
            }
            
            self.vpnManager = managers.first(where: { [unowned self] (manager) -> Bool in
                return (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.bundleId
            }) ?? NETunnelProviderManager()

            completion(self.vpnManager, nil)
        }
    }
    
    private func openVpnConfiguration(for connectionConfiguration: VpnManagerConfiguration) -> OpenVPN.Configuration {
        var configurationBuilder = OpenVPN.ConfigurationBuilder()
        configurationBuilder.ca = OpenVpnProtocolFactory.certificateAuthority
        configurationBuilder.tlsWrap = OpenVPN.TLSWrap(strategy: .auth, key: OpenVpnProtocolFactory.tlsKey)
        configurationBuilder.cipher = .aes256cbc
        configurationBuilder.digest = .sha512
        configurationBuilder.compressionFraming = .compress
        configurationBuilder.renegotiatesAfter = 0
        configurationBuilder.hostname = connectionConfiguration.entryServerAddress
        configurationBuilder.checksEKU = true
        configurationBuilder.checksSANHost = true
        configurationBuilder.sanHost = connectionConfiguration.hostname
        configurationBuilder.mtu = 1250
        
        let socketType = socketTypeFor(connectionConfiguration.vpnProtocol)
        
        let ports: [Int]
        switch socketType {
        case .tcp, .tcp4, .tcp6:
            ports = portsConfig().defaultTcpPorts.shuffled()
        case .udp, .udp4, .udp6:
            ports = portsConfig().defaultUdpPorts.shuffled()
        }
        
        configurationBuilder.endpointProtocols = ports.map({ (port) -> EndpointProtocol in
            return EndpointProtocol(socketType, (UInt16(port)))
        })
        
        return configurationBuilder.build()
    }
    
    private func socketTypeFor(_ vpnProtocol: VpnProtocol) -> SocketType {
        let socketType: SocketType
        if case VpnProtocol.openVpn(let transportProtocol) = vpnProtocol {
            switch transportProtocol {
            case .tcp, .undefined:
                socketType = .tcp
            case .udp:
                socketType = .udp
            }
        } else {
            socketType = .tcp
        }
        
        return socketType
    }
    
    private func tunnelProviderGenerator(for openVpnConfiguration: OpenVPN.Configuration) -> OpenVPNTunnelProvider.Configuration {
        var configurationBuilder = OpenVPNTunnelProvider.ConfigurationBuilder(sessionConfiguration: openVpnConfiguration)
        configurationBuilder.shouldDebug = true // FUTURETODO: set based on the user's preference
        configurationBuilder.masksPrivateData = true
        
        return configurationBuilder.build()
    }
    
    private func portsConfig() -> OpenVpnConfig {
        return propertiesManager.openVpnConfig ?? OpenVpnConfig(defaultTcpPorts: [443, 3389, 8080, 8443],
                                                                defaultUdpPorts: [443, 1194, 4569, 5060, 80])
    }
    
    private func logData(completion: @escaping (Data?) -> Void) {
        guard let connection = vpnManager?.connection as? NETunnelProviderSession else {
            completion(nil)
            return
        }
        
        do {
            try connection.sendProviderMessage(OpenVPNTunnelProvider.Message.requestLog.data) { (data) in
                guard let data = data, !data.isEmpty else {
                    completion(nil)
                    return
                }
                
                completion(data)
            }
        } catch {
            completion(nil)
        }
    }
    
}
