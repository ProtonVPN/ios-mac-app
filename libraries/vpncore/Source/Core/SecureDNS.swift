//
//  SecureDNS.swift
//  Core
//
//  Created by Jack Kim-Biggs on 11/4/21.
//  Copyright © 2021 Jack Kim-Biggs. All rights reserved.
//

import Foundation
import Alamofire

public enum SecureDNSProtocol: Int, CaseIterable {
    case off = 0
    case DoH
    case DoT

    public var localizedString: String {
        switch self {
        case .off:
            return LocalizedString.secureDnsOff
        case .DoH:
            return LocalizedString.secureDnsOverHttps
        case .DoT:
            return LocalizedString.secureDnsOverTls
        }
    }
}

#if canImport(NetworkExtension)
import NetworkExtension

@available(iOS 14.0, macOS 11.0, *)
extension NEDNSSettings {
    /// NB: These configuration values will be invalid on Nov 18 2021. You can get a free NextDNS
    /// trial account, good for another 7 days, at https://nextdns.io .
    static let dnsServerNames: [String] = [
        "45.90.28.138",
        "45.90.30.138",
        "2a07:a8c0::1d:67f2",
        "2a07:a8c1::1d:67f2",
    ]

    static let defaultDoHProvider: NEDNSOverHTTPSSettings = {
        var settings = NEDNSOverHTTPSSettings(servers: NEDNSSettings.dnsServerNames)
        settings.serverURL = URL(string: "https://dns.nextdns.io/1d67f2")!
        settings.searchDomains = nil
        return settings
    }()

    static let defaultDoTProvider: NEDNSOverTLSSettings = {
        var settings = NEDNSOverTLSSettings(servers: NEDNSSettings.dnsServerNames)
        settings.serverName = "1d67f2.dns.nextdns.io"
        settings.searchDomains = nil
        return settings
    }()
}

@available(iOS 14.0, macOS 11.0, *)
extension SecureDNSProtocol {
    public var dnsSettings: NEDNSSettings? {
        switch self {
        case .off:
            return nil
        case .DoH:
            return .defaultDoHProvider
        case .DoT:
            return .defaultDoTProvider
        }
    }
}
#endif
