//
//  SecureDNSViewModel.swift
//  ProtonVPN
//
//  Created by Jack Kim-Biggs on 11/4/21.
//  Copyright © 2021 Jack Kim-Biggs. All rights reserved.
//

import Foundation
import vpncore
import UIKit

final class SecureDNSViewModel {
    /// URL to the VPN/DNS section of the Settings app.
    static let dnsSettingsURLString: String = "prefs:root=General&path=VPN/DNS"

    var contentChanged: (() -> Void)?

    typealias TypeChangeCallback = ((SecureDNSProtocol) -> Void)
    var protocolChanged: TypeChangeCallback?

    private var dnsProtocol: SecureDNSProtocol = .off
    private let featureFlags: FeatureFlags
    private let alertService: AlertService
    private let safariService: SafariServiceProtocol
    private var dnsManager: DNSSettingsManagerProtocol

    init(dnsProtocol: SecureDNSProtocol, featureFlags: FeatureFlags, alertService: AlertService, safariService: SafariServiceProtocol, dnsManager: DNSSettingsManagerProtocol) {
        self.dnsProtocol = dnsProtocol
        self.featureFlags = featureFlags
        self.alertService = alertService
        self.safariService = safariService
        self.dnsManager = dnsManager
    }

    var tableViewData: [TableViewSection] {
        return [dnsProtocols]
    }

    private var dnsProtocols: TableViewSection {
        let cells: [TableViewCellModel] = SecureDNSProtocol.allCases.map { proto in
            .checkmarkStandard(title: proto.localizedString, checked: dnsProtocol == proto, handler: { [weak self] in
                guard let `self` = self else { return false }

                self.dnsProtocol = proto
                guard #available(iOS 14, *) else { return true }

                self.dnsManager.loadFromPreferences { maybeErr in
                    if let err = maybeErr {
                        PMLog.printToConsole("Could not load from preferences: \(err)")
                        return
                    }
                    self.switchDnsProtocol(proto)
                }
                return true
            })
        }

        return TableViewSection(title: "", showHeader: false, cells: cells)
    }

    @available(iOS 14, *)
    private func switchDnsProtocol(_ dnsProtocol: SecureDNSProtocol) {
        switch dnsProtocol {
        case .off:
            dnsManager.removeFromPreferences { maybeErr in
                guard let err = maybeErr else { return }
                PMLog.printToConsole("Could not remove from preferences: \(err)")
            }
        default:
            dnsManager.dnsSettings = dnsProtocol.dnsSettings
            dnsManager.saveToPreferences { [weak self] maybeErr in
                if let err = maybeErr {
                    PMLog.printToConsole("Could not save to preferences: \(err)")
                    return
                }

                if self?.dnsManager.isEnabled == false {
                    self?.alertService.push(alert: DNSNotEnabledAlert {
                        // TODOFUTURE: This isn't working yet, likely because the prefs URL scheme
                        // isn't approved for use by this app.
                        self?.safariService.open(url: SecureDNSViewModel.dnsSettingsURLString)
                    })
                }
            }
        }
        stateUpdated()
    }

    private func stateUpdated() {
        protocolChanged?(dnsProtocol)
        contentChanged?()
    }
}
