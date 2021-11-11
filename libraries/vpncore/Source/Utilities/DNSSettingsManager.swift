//
//  DNSSettingsManager.swift
//  Core
//
//  Created by Jack Kim-Biggs on 11/4/21.
//  Copyright © 2021 Jack Kim-Biggs. All rights reserved.
//

import Foundation
import NetworkExtension

public protocol DNSSettingsManagerProtocol {
    func loadFromPreferences(completionHandler: @escaping (Error?) -> Void)
    func saveToPreferences(completionHandler: @escaping (Error?) -> Void)
    func removeFromPreferences(completionHandler: @escaping (Error?) -> Void)

    var isEnabled: Bool { get }
    var dnsSettings: NEDNSSettings? { get set }
    var localizedDescription: String? { get set }
    var onDemandRules: [NEOnDemandRule]? { get set }
}

public protocol DNSSettingsManagerFactory {
    func makeDNSSettingsManager() -> DNSSettingsManagerProtocol?
}

@available(iOS 14.0, macOS 11.0, *)
extension NEDNSSettingsManager: DNSSettingsManagerProtocol {
}
