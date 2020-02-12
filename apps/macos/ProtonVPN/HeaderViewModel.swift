//
//  HeaderViewModel.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Cocoa
import vpncore

protocol HeaderViewModelDelegate: class {
    
    func bitrateUpdated(with attributedString: NSAttributedString)
}

class HeaderViewModel {
    
    private let vpnGateway: VpnGatewayProtocol
    private let propertiesManager = PropertiesManager()
    private let serverStorage = ServerStorageConcrete()
    private let profileManager: ProfileManager
    private let navService: NavigationService
    
    var contentChanged: (() -> Void)?
    
    var statistics: NetworkStatistics?
    weak var delegate: HeaderViewModelDelegate? {
        didSet {
            if delegate != nil, isConnected {
                startBitrateStatistics()
            }
        }
    }
    
    init(vpnGateway: VpnGatewayProtocol, navService: NavigationService) {
        self.vpnGateway = vpnGateway
        self.navService = navService
        profileManager = ProfileManager.shared
        startObserving()
    }
    
    var isConnected: Bool {
        return vpnGateway.connection == .connected
    }
    
    var connectedCountryCode: String? {
        return vpnGateway.activeServer?.countryCode
    }
    
    var headerLabel: NSAttributedString {
        return formHeaderLabel()
    }
    
    var ipLabel: NSAttributedString {
        return formIpLabel()
    }
    
    var loadLabel: NSAttributedString? {
        return formLoadLabel()
    }
    
    var loadLabelShort: NSAttributedString? {
        return formLoadLabelShort()
    }
    
    var loadPercentage: Int? {
        return vpnGateway.activeServer?.load
    }
    
    func quickConnectAction() {
        isConnected ? vpnGateway.disconnect() : vpnGateway.quickConnect()
    }

    // MARK: - Private functions
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConnectionChanged), name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConnectionChanged), name: VpnGateway.connectionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(contentChangedNotification), name: type(of: propertiesManager).userIpNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(contentChangedNotification), name: profileManager.contentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(contentChangedNotification), name: serverStorage.contentChanged, object: nil)
    }
    
    @objc private func vpnConnectionChanged() {
        if vpnGateway.connection == .connected {
            startBitrateStatistics()
        } else {
            statistics?.stopGathering()
            statistics = nil
        }
        
        contentChanged?()
    }
    
    @objc private func contentChangedNotification() {
        contentChanged?()
    }
    
    private func formBitrateLabel(with bitrate: Bitrate) -> NSAttributedString {
        let downloadString = " \(rateString(for: bitrate.download))  ".attributed(withColor: NSColor.protonWhite(), fontSize: 12)
        let uploadString = " \(rateString(for: bitrate.upload))".attributed(withColor: NSColor.protonWhite(), fontSize: 12)
        let downloadIcon = NSAttributedString.imageAttachment(named: "bitrate-download-arrow", width: 12, height: 12)!
        let uploadIcon = NSAttributedString.imageAttachment(named: "bitrate-upload-arrow", width: 12, height: 12)!
        
        return NSAttributedString.concatenate(downloadIcon, downloadString, uploadIcon, uploadString)
    }
    
    private func startBitrateStatistics() {
        statistics?.stopGathering()
        statistics = nil
        
        statistics = NetworkStatistics(with: 1.0) { [weak self] (bitrate) in
            guard let `self` = self, let delegate = self.delegate else { return }
            delegate.bitrateUpdated(with: self.formBitrateLabel(with: bitrate))
        }
    }
    
    private func rateString(for rate: UInt32) -> String {
        let rateString: String
        
        switch rate {
        case let rate where rate >= UInt32(pow(1024.0, 3)):
            rateString = "\(String(format: "%.1f", Double(rate) / pow(1024.0, 3))) GB/s"
        case let rate where rate >= UInt32(pow(1024.0, 2)):
            rateString = "\(String(format: "%.1f", Double(rate) / pow(1024.0, 2))) MB/s"
        case let rate where rate >= 1024:
            rateString = "\(String(format: "%.1f", Double(rate) / 1024.0)) KB/s"
        default:
            rateString = "\(String(format: "%.1f", Double(rate))) B/s"
        }
        
        return rateString
    }
    
    private func formHeaderLabel() -> NSAttributedString {
        if !isConnected {
            return LocalizedString.youAreNotConnected.attributed(withColor: .protonRed(), fontSize: 16, bold: true, alignment: .left)
        }
        
        guard let server = vpnGateway.activeServer else {
            return LocalizedString.noDescriptionAvailable.attributed(withColor: .protonWhite(), fontSize: 16, bold: false, alignment: .left)
        }
        
        let doubleArrows = NSAttributedString.imageAttachment(named: "double-arrow-right-white", width: 10, height: 10)!
        
        if server.isSecureCore {
            let secureCoreIcon = NSAttributedString.imageAttachment(named: "protonvpn-server-sc-available", width: 14, height: 14)!
            let entryCountry = (" " + server.entryCountry + " ").attributed(withColor: .protonGreen(), fontSize: 16, bold: false, alignment: .left)
            let exitCountry = (" " + server.exitCountry + " ").attributed(withColor: .protonWhite(), fontSize: 16, bold: false, alignment: .left)
            return NSAttributedString.concatenate(secureCoreIcon, entryCountry, doubleArrows, exitCountry)
        } else {
            let country = (server.country + " ").attributed(withColor: .protonWhite(), fontSize: 16, bold: false, alignment: .left)
            let serverName = server.name.attributed(withColor: .protonWhite(), fontSize: 16, bold: false, alignment: .left)
            return NSAttributedString.concatenate(country, serverName)
        }
    }
    
    private func formIpLabel() -> NSAttributedString {
        let ip = String(format: LocalizedString.ipValue, getCurrentIp() ?? LocalizedString.unavailable)
        let attributedString = NSMutableAttributedString(attributedString: ip.attributed(withColor: .protonWhite(), fontSize: 14, alignment: .left))
        let ipRange = (ip as NSString).range(of: getCurrentIp() ?? LocalizedString.unavailable)
        attributedString.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: ipRange)
        return attributedString
    }
    
    private func getCurrentIp() -> String? {
        if isConnected {
            return vpnGateway.activeIp
        } else {
            return propertiesManager.userIp
        }
    }
    
    private func formLoadLabel() -> NSAttributedString? {
        guard let server = vpnGateway.activeServer else {
            return nil
        }
        return ("\(server.load)% " + LocalizedString.load).attributed(withColor: .protonWhite(),
                                                                  fontSize: 12,
                                                                  alignment: .right)
    }
    
    private func formLoadLabelShort() -> NSAttributedString? {
        guard let server = vpnGateway.activeServer else {
            return nil
        }
        return ("\(server.load)%").attributed(withColor: .protonWhite(),
                                                                  fontSize: 12,
                                                                  alignment: .right)
    }
    
    private func formProfileButtonLabel() -> NSAttributedString? {
        guard let server = vpnGateway.activeServer else {
            return nil
        }
        
        if let profile = profileManager.profile(withServer: server) {
            let deleteText = ("  " + profile.name).attributed(withColor: .protonWhite(), fontSize: 13, alignment: .left, lineBreakMode: .byTruncatingTail)
            let attributedString = NSMutableAttributedString(attributedString: NSAttributedString.concatenate(profile.profileIcon.attributedAttachment(width: 10), deleteText))
            let range = (attributedString.string as NSString).range(of: attributedString.string)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            return attributedString
        } else {
            let saveIcon = NSAttributedString.imageAttachment(named: "save_profile")!
            let saveText = (" " + LocalizedString.saveAsProfile).attributed(withColor: .protonGreen(), fontSize: 13, alignment: .left)
            return NSAttributedString.concatenate(saveIcon, saveText)
        }
    }
}
