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

protocol HeaderViewModelFactory {
    func makeHeaderViewModel() -> HeaderViewModel
}

final class HeaderViewModel {
    
    public typealias Factory = AnnouncementManagerFactory & AppStateManagerFactory & PropertiesManagerFactory & CoreAlertServiceFactory & ProfileManagerFactory & NavigationServiceFactory & VpnGatewayFactory & AnnouncementsViewModelFactory
    private let factory: Factory
    
    private let serverStorage = ServerStorageConcrete()
    
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var announcementManager: AnnouncementManager = factory.makeAnnouncementManager()
    private lazy var announcementsViewModel: AnnouncementsViewModel = factory.makeAnnouncementsViewModel()
    
    var contentChanged: (() -> Void)?
    
    var statistics: NetworkStatistics?
    weak var delegate: HeaderViewModelDelegate? {
        didSet {
            if delegate != nil, isConnected {
                startBitrateStatistics()
            }
        }
    }
    
    init(factory: Factory, appStateManager: AppStateManager, navService: NavigationService) {
        self.factory = factory
        startObserving()
    }
    
    var isConnected: Bool {
        return vpnGateway.connection == .connected
    }
    
    var connectedCountryCode: String? {
        return appStateManager.activeConnection()?.server.countryCode
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
        return formLoadLabel(short: true)
    }
    
    var loadPercentage: Int? {
        return appStateManager.activeConnection()?.server.load
    }

    var vpnProtocol: NSAttributedString? {
        guard let vpnProtocol = appStateManager.activeConnection()?.vpnProtocol else {
            return nil
        }

        let name: String
        switch vpnProtocol {
        case .ike:
            name = LocalizedString.ikev2
        case let .openVpn(transport):
            switch transport {
            case .tcp:
                name = "\(LocalizedString.openvpn) (\(LocalizedString.tcp))"
            case .udp:
                name = "\(LocalizedString.openvpn) (\(LocalizedString.udp))"
            }
        case .wireGuard:
            name = LocalizedString.wireguard
        }

        return name.styled(font: .themeFont(.small))
    }

    var isVisible: Bool = false {
        didSet {
            guard isVisible else {
                statistics?.stopGathering()
                statistics = nil
                return
            }

            startBitrateStatistics()
        }
    }
    
    func quickConnectAction() {
        if isConnected {
            log.debug("Disconnect requested by selecting Quick connect", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else {
            log.debug("Connect requested by selecting Quick connect", category: .connectionConnect, event: .trigger)
            vpnGateway.quickConnect()
        }
    }
    
    // MARK: - Announcements bell
    
    var showAnnouncements: Bool {
        guard propertiesManager.featureFlags.pollNotificationAPI else {
            return false
        }
        return !announcementManager.fetchCurrentAnnouncements().isEmpty
    }
    
    var hasUnreadAnnouncements: Bool {
        return announcementManager.hasUnreadAnnouncements
    }

    var announcementIconUrl: URL? {
        if let icon = announcementsViewModel.currentItem?.offer?.icon, let url = URL(string: icon) {
            return url
        }
        return nil
    }

    var announcementTooltip: String? {
        return announcementsViewModel.currentItem?.offer?.panel?.title ?? announcementsViewModel.currentItem?.offer?.label
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
        guard isVisible else {
            return
        }

        if isConnected {
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
        let downloadString = " \(rateString(for: bitrate.download))  ".styled(font: .themeFont(.small))
        let uploadString = " \(rateString(for: bitrate.upload))".styled(font: .themeFont(.small))
        let downloadIcon = AppTheme.Icon.arrowDown.asAttachment(style: .normal, size: .square(12))
        let uploadIcon = AppTheme.Icon.arrowUp.asAttachment(style: .normal, size: .square(12))

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
            return LocalizedString.youAreNotConnected.styled(.danger, font: .themeFont(.heading4, bold: true), alignment: .left)
        }
        
        guard let server = appStateManager.activeConnection()?.server else {
            return LocalizedString.noDescriptionAvailable.styled(font: .themeFont(.heading4), alignment: .left)
        }
        
        let doubleArrows = AppTheme.Icon.chevronsRight.asAttachment(style: .normal, size: .square(10))
        
        if server.isSecureCore {
            let secureCoreIcon = AppTheme.Icon.shield.asAttachment(style: .normal, size: .square(14))
            let entryCountry = (" " + server.entryCountry + " ").styled(.normal, font: .themeFont(.heading4), alignment: .left)
            let exitCountry = (" " + server.exitCountry + " ").styled(font: .themeFont(.heading4), alignment: .left)
            return NSAttributedString.concatenate(secureCoreIcon, entryCountry, doubleArrows, exitCountry)
        } else {
            let country = (server.country + " ").styled(font: .themeFont(.heading4), alignment: .left)
            let serverName = server.name.styled(font: .themeFont(.heading4), alignment: .left)
            return NSAttributedString.concatenate(country, serverName)
        }
    }
    
    private func formIpLabel() -> NSAttributedString {
        let ip = LocalizedString.ipValue(getCurrentIp() ?? LocalizedString.unavailable)
        let attributedString = NSMutableAttributedString(attributedString: ip.styled(alignment: .left))
        let ipRange = (ip as NSString).range(of: getCurrentIp() ?? LocalizedString.unavailable)
        attributedString.addAttribute(.font, value: NSFont.themeFont(bold: true), range: ipRange)
        return attributedString
    }
    
    private func getCurrentIp() -> String? {
        if isConnected {
            return appStateManager.activeConnection()?.serverIp.exitIp
        } else {
            return propertiesManager.userIp
        }
    }
    
    private func formLoadLabel(short: Bool = false) -> NSAttributedString? {
        guard let server = appStateManager.activeConnection()?.server else {
            return nil
        }
        let includeLoad = short ? "" : " \(LocalizedString.load)"
        return ("\(server.load)%" + includeLoad).styled(font: .themeFont(.small), alignment: .right)
    }

    private func formProfileButtonLabel() -> NSAttributedString? {
        guard let server = appStateManager.activeConnection()?.server else {
            return nil
        }
        
        if let profile = profileManager.profile(withServer: server) {
            let deleteText = ("  " + profile.name).styled(font: .themeFont(literalSize: 13), alignment: .left, lineBreakMode: .byTruncatingTail)
            let attributedString = NSMutableAttributedString(attributedString: NSAttributedString.concatenate(profile.profileIcon.attributedAttachment(width: 10), deleteText))
            let range = (attributedString.string as NSString).range(of: attributedString.string)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            return attributedString
        } else {
            let saveIcon = NSAttributedString.imageAttachment(named: "save_profile")!
            let saveText = (" " + LocalizedString.saveAsProfile).styled(.interactive, font: .themeFont(literalSize: 13), alignment: .left)
            return NSAttributedString.concatenate(saveIcon, saveText)
        }
    }
}
