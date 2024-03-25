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
import Dependencies
import Ergonomics
import LegacyCommon
import VPNShared
import Theme
import Strings

protocol HeaderViewModelDelegate: AnyObject {
    func bitrateUpdated(with attributedString: NSAttributedString)
    func changeServerStateUpdated(to state: ServerChangeViewState)
}

protocol HeaderViewModelFactory {
    func makeHeaderViewModel() -> HeaderViewModel
}

final class HeaderViewModel {
    @Dependency(\.featureFlagProvider) var featureFlags
    @Dependency(\.credentialsProvider) var credentials
    
    public typealias Factory = AnnouncementManagerFactory & AppStateManagerFactory & PropertiesManagerFactory & CoreAlertServiceFactory & ProfileManagerFactory & NavigationServiceFactory & VpnGatewayFactory & AnnouncementsViewModelFactory
    private let factory: Factory
    
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var announcementManager: AnnouncementManager = factory.makeAnnouncementManager()
    private lazy var announcementsViewModel: AnnouncementsViewModel = factory.makeAnnouncementsViewModel()

    var contentChanged: (() -> Void)?
    /// It's the same as delegates `changeServerStateUpdated(to:)` method, but is used by a parent view, to connect
    /// this VM with a countries VM, that has to change the banner in case there is a change server timer running.
    var changeServerStateUpdated: ((ServerChangeViewState) -> Void)?

    var shouldShowChangeServer: Bool {
        isConnected && featureFlags[\.showNewFreePlan] && credentials.tier.isFreeTier
    }

    private var serverChangeTimer: Timer?
    private var lastChangeServerAvailableState: ServerChangeAuthorizer.ServerChangeAvailability?

    var canChangeServer: ServerChangeAuthorizer.ServerChangeAvailability {
        if let lastState = lastChangeServerAvailableState, case .unavailable(let until, _, _) = lastState, until.isFuture {
            // Don't re-calculate server change availability if we know we don't need to
            // (if we are already in time-out, this won't change unless we upgrade)
            return lastState
        }

        @Dependency(\.serverChangeAuthorizer) var authorizer
        let freshState = authorizer.serverChangeAvailability()

        if case .unavailable = freshState, serverChangeTimer == nil {
            serverChangeTimer = .scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerTicked), userInfo: nil, repeats: true)
        }
        lastChangeServerAvailableState = freshState
        return freshState
    }
    
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

        return vpnProtocol.localizedString.styled(font: .themeFont(.small))
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
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.quick))
            log.debug("Disconnect requested by selecting Quick connect", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.connect)
            log.debug("Connect requested by selecting Quick connect", category: .connectionConnect, event: .trigger)
            vpnGateway.quickConnect(trigger: .quick)
        }
    }

    func changeServerAction() {
        vpnGateway.connectTo(profile: ProfileConstants.randomProfile(connectionProtocol: propertiesManager.connectionProtocol, defaultProfileAccessTier: 0))
    }

    @objc private func timerTicked() {
        let viewState = ServerChangeViewState.from(state: canChangeServer)
        delegate?.changeServerStateUpdated(to: viewState)
        changeServerStateUpdated?(viewState)
        if case .available = viewState {
            serverChangeTimer?.invalidate()
            serverChangeTimer = nil
        }
    }
    
    // MARK: - Announcements bell
    
    var showAnnouncements: Bool {
        guard propertiesManager.featureFlags.pollNotificationAPI else {
            return false
        }
        return announcementManager.fetchCurrentAnnouncementsFromStorage().contains(where: { $0.knownType == .default })
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

    func prefetchImages() async {
        let urls = announcementsViewModel.backgroundURLs()
        guard !urls.isEmpty else {
            log.debug("No URLs to prefetch")
            return
        }
        log.debug("Prefetching urls: \(urls)")
        await FullScreenImagePrefetcher(ImageCacheFactory()).prefetchImages(urls: urls)
    }

    var announcementTooltip: String? {
        return announcementsViewModel.currentItem?.offer?.panel?.title ?? announcementsViewModel.currentItem?.offer?.label
    }
    
    // MARK: - Private functions
    
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConnectionChanged), name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConnectionChanged), name: VpnGateway.connectionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(contentChangedNotification), name: type(of: propertiesManager).userIpNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(contentChangedNotification), name: type(of: propertiesManager).activeConnectionChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(contentChangedNotification), name: profileManager.contentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(contentChangedNotification), name: ServerListUpdateNotification.name, object: nil)
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
        executeOnUIThread {
            self.contentChanged?()
        }
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
            guard let self = self else {
                return
            }

            self.delegate?.bitrateUpdated(with: self.formBitrateLabel(with: bitrate))
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
            return Localizable.youAreNotConnected.styled(.danger, font: .themeFont(.heading4, bold: true), alignment: .left)
        }
        
        guard let server = appStateManager.activeConnection()?.server else {
            return Localizable.noDescriptionAvailable.styled(font: .themeFont(.heading4), alignment: .left)
        }

        let font = NSFont.themeFont(.heading4)
        if server.isSecureCore {
            let secureCoreIcon = AppTheme.Icon.locks.asAttachment(style: .normal, size: .square(16), centeredVerticallyForFont: font)
            let entryCountry = (" " + server.entryCountry + " ").styled(.normal, font: font, alignment: .left)
            let doubleArrows = AppTheme.Icon.chevronsRight.asAttachment(style: .normal, size: .square(16), centeredVerticallyForFont: font)
            let exitCountry = (" " + server.exitCountry + " ").styled(font: font, alignment: .left)
            return NSAttributedString.concatenate(secureCoreIcon, entryCountry, doubleArrows, exitCountry)
        } else {
            let country = (server.country + " ").styled(font: font, alignment: .left)
            let serverName = server.name.styled(font: font, alignment: .left)
            return NSAttributedString.concatenate(country, serverName)
        }
    }
    
    private func formIpLabel() -> NSAttributedString {
        let ip = Localizable.ipValue(getCurrentIp() ?? Localizable.unavailable)
        let attributedString = NSMutableAttributedString(attributedString: ip.styled(alignment: .left))
        let ipRange = (ip as NSString).range(of: getCurrentIp() ?? Localizable.unavailable)
        attributedString.addAttribute(.font, value: NSFont.themeFont(bold: true), range: ipRange)
        return attributedString
    }
    
    private func getCurrentIp() -> String? {
        if isConnected {
            return appStateManager.activeConnection()?.serverIp.exitIp
        } else {
            return propertiesManager.userLocation?.ip
        }
    }
    
    private func formLoadLabel(short: Bool = false) -> NSAttributedString? {
        guard let server = appStateManager.activeConnection()?.server else {
            return nil
        }
        return (short ? "\(server.load)%" : Localizable.serverLoadPercentage(server.load))
            .styled(font: .themeFont(.small), alignment: .right)
    }
}
