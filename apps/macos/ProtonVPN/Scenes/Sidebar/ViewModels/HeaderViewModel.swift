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

import Announcement
import Cocoa
import Combine
import CommonNetworking
import ComposableArchitecture
import Connection
import ConnectionInventory
import Dependencies
import Domain
import Ergonomics
import Localization
import Sharing
import Strings
import Theme
import VPNAppCore
import VPNShared

protocol HeaderViewModelDelegate: AnyObject {
    func bitrateUpdated(with attributedString: NSAttributedString)
    func changeServerStateUpdated(to state: ServerChangeViewState)
    func mappedPortChanged(to mappedPort: UInt16?)
}

final class HeaderViewModel {
    @Dependency(\.credentialsProvider) var credentials
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.coreAlertService) private var coreAlertService
    @SharedReader(.killSwitchMode) private var killSwitchMode: KillSwitchMode

    private var advancedKillSwitchActive: Bool {
        killSwitchMode.isAdvanced && connectionState.tunnelKillSwitch
    }

    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider
    @Dependency(\.serverRepository) private var serverRepository
    @SharedReader(.userLocation) private var userLocation: UserLocation?
    @Dependency(\.announcementManager) private var announcementManager
    @Dependency(\.notificationManager) private var notificationManager

    var contentChanged: (() -> Void)?
    /// It's the same as delegates `changeServerStateUpdated(to:)` method, but is used by a parent view, to connect
    /// this VM with a countries VM, that has to change the banner in case there is a change server timer running.
    var changeServerStateUpdated: ((ServerChangeViewState) -> Void)?

    var shouldShowChangeServer: Bool {
        isConnected && credentials.tier.isFree
    }

    private var serverChangeTimer: Timer?

    var canChangeServer: ServerChangeAuthorizer.ServerChangeAvailability {
        @Dependency(\.serverChangeAuthorizer) var authorizer
        let freshState = authorizer.serverChangeAvailability()

        if case .unavailable = freshState, serverChangeTimer == nil {
            serverChangeTimer = .scheduledTimer(
                timeInterval: 1.0,
                target: self,
                selector: #selector(timerTicked),
                userInfo: nil,
                repeats: true
            )
        }
        return freshState
    }

    private var natPmpCancellable: AnyCancellable?
    private var portForwardingObserverTask: Task<Void, Never>?
    @SharedReader(.connectionState) private var connectionState: ConnectionState
    private var cancellables = Set<AnyCancellable>()

    var statistics: NetworkStatistics?
    weak var delegate: HeaderViewModelDelegate? {
        didSet {
            if delegate != nil, isConnected {
                startBitrateStatistics()
                startNatPmpObservation()
            }
        }
    }

    init() {
        startObserving()
    }

    deinit {
        portForwardingObserverTask?.cancel()
    }

    var isConnected: Bool {
        connectionState.isConnected
    }

    var isAuthenticationRequired: Bool {
        connectionState.is(\.authenticationRequired)
    }

    var isKillSwitchBlocking: Bool {
        connectionState.is(\.killSwitchActive)
    }

    var connectedCountryCode: String? {
        connectedServer?.logical.exitCountryCode
    }

    var headerLabel: NSAttributedString {
        formHeaderLabel()
    }

    var ipLabel: NSAttributedString {
        formIpLabel()
    }

    var loadLabel: NSAttributedString? {
        formLoadLabel()
    }

    var loadLabelShort: NSAttributedString? {
        formLoadLabel(short: true)
    }

    var loadPercentage: Int? {
        connectedServer?.logical.load
    }

    var vpnProtocol: NSAttributedString? {
        guard let vpnProtocol = connectionState.resolvedVpnProtocol else {
            return nil
        }

        return vpnProtocol.localizedDescription.styled(font: .themeFont(.small), alignment: .left)
    }

    var isVisible: Bool = false {
        didSet {
            guard isVisible else {
                statistics?.stopGathering()
                statistics = nil
                return
            }

            contentChanged?()
            startBitrateStatistics()
        }
    }

    func quickConnectAction() {
        if isConnected || isAuthenticationRequired {
            // Advanced KS keeps blocking after an intentional disconnect, so confirm first, but only when it's Active
            // (armed at connect). If it's merely Armed (enabled mid-session), a disconnect is a normal release with no
            // warning, since KS isn't in effect until the next connection.
            if advancedKillSwitchActive {
                coreAlertService.push(alert: DisconnectWithAdvancedKillSwitchAlert(confirmHandler: { [connectionCommandClient] in
                    log.debug("Disconnect confirmed with Advanced kill switch active", category: .connectionDisconnect, event: .trigger)
                    connectionCommandClient.send(.disconnect(.quick))
                }))
                return
            }
            log.debug("Disconnect requested by selecting Quick connect", category: .connectionDisconnect, event: .trigger)
            connectionCommandClient.send(.disconnect(.quick))
        } else {
            log.debug("Connect requested by selecting Quick connect", category: .connectionConnect, event: .trigger)
            connectionCommandClient.quickConnect(trigger: .quick)
        }
    }

    func changeServerAction() {
        let spec = ConnectionSpec(location: .any(.random), features: [])
        @SharedReader(.connectionProtocol) var connectionProtocol
        connectionCommandClient.send(.connect(spec, connectionProtocol, .changeServer))
    }

    @objc
    private func timerTicked() {
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
        @SharedReader(.featureFlags) var featureFlags
        guard featureFlags.pollNotificationAPI else {
            return false
        }
        return announcementManager.fetchCurrentAnnouncementsFromStorage().contains(where: { $0.knownType == .default })
    }

    var hasUnreadAnnouncements: Bool {
        announcementManager.hasUnreadAnnouncements()
    }

    var announcementIconUrl: URL? {
        announcementManager.announcementIconURL
    }

    func prefetchImages() async {
        let urls = announcementManager.offerImagePrefetchURLs()
        guard !urls.isEmpty else {
            log.debug("No URLs to prefetch")
            return
        }
        log.debug("Prefetching urls: \(urls)")
        @Dependency(\.imagePrefetcher) var imagePrefetcher
        await imagePrefetcher.prefetchURLs(urls)
    }

    var announcementTooltip: String? {
        let offer = announcementManager.currentOfferAnnouncement?.offer
        return offer?.panel?.title ?? offer?.label
    }

    // MARK: - Private functions

    private func startObserving() {
        $connectionState.publisher
            .sink { [weak self] newValue in
                self?.vpnConnectionChanged(newValue)
            }
            .store(in: &cancellables)

        let contentChangedEvents: [AppEvent] = [
            .profileContentChanged,
        ]
        contentChangedEvents.subscribe(self, selector: #selector(contentChangedNotification))

        $userLocation
            .publisher
            .sink { [weak self] _ in self?.contentChangedNotification() }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentChangedNotification),
            name: ServerListUpdateNotification.name,
            object: nil
        )

        // Observe port forwarding changes via AsyncStream
        portForwardingObserverTask = Task { [weak self] in
            guard let self else { return }
            let stream = portForwardingPropertyProvider.portForwardingStream()
            for await _ in stream {
                try? Task.checkCancellation()
                await MainActor.run {
                    self.vpnConnectionChanged()
                }
            }
        }
    }

    @objc
    private func vpnConnectionChanged() {
        // Called from outside the publisher sink (e.g., the port-forwarding stream). It's safe to read
        // `connectionState` synchronously here because we're not inside a willSet.
        vpnConnectionChanged(connectionState)
    }

    private func vpnConnectionChanged(_ state: ConnectionState) {
        // Read `isConnected` from the `state` parameter rather than the `self.connectionState` accessor. swift-sharing
        // fires the publisher inside the storage's `willSet`, so the synchronous accessor still returns the *previous*
        // value at this point. Using `state` ensures we react to the actual new value (e.g. starting NAT-PMP
        // observation when transitioning into `.connected`).
        let isConnected = state.isConnected
        if isConnected {
            startNatPmpObservation()
            if isVisible {
                startBitrateStatistics()
            }
        } else {
            natPmpCancellable = nil
            delegate?.mappedPortChanged(to: nil)
            statistics?.stopGathering()
            statistics = nil
        }

        // Use UI runloop to re-read `connectionState`
        DispatchQueue.main.async { [weak self] in
            self?.contentChanged?()
        }
    }

    @objc
    private func contentChangedNotification() {
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

        statistics = NetworkStatistics(with: 1.0) { [weak self] bitrate in
            guard let self else {
                return
            }

            delegate?.bitrateUpdated(with: formBitrateLabel(with: bitrate))
        }
    }

    private func startNatPmpObservation() {
        guard VPNFeatureFlagType.portForwarding.enabled else { return }
        natPmpCancellable = nil
        guard portForwardingPropertyProvider.getPortForwarding() == true else {
            delegate?.mappedPortChanged(to: nil)
            return
        }
        @Dependency(\.natPortMappingService) var natPortMappingService
        natPmpCancellable = natPortMappingService.portMappingStream
            .removeDuplicates(by: { prevResult, nextResult in
                switch (prevResult, nextResult) {
                case let (.success(prevPortMapping), .success(nextPortMapping)):
                    // consume next value only if mapped ports are not the same
                    prevPortMapping?.mappedExternalPort == nextPortMapping?.mappedExternalPort
                case (.success, .failure), (.failure, .success):
                    false
                case (.failure, .failure):
                    // we don't differentiate errors; thus all subsequent errors are "equal"
                    true
                }
            })
            .sink(receiveCompletion: { [weak self] _ in
                self?.delegate?.mappedPortChanged(to: nil)
            }, receiveValue: { [weak self] portMappingResult in
                switch portMappingResult {
                case let .success(portMapping):
                    guard let portMapping, portMapping.deadlineDate > Date() else {
                        // not valid port mapping, hide it
                        self?.delegate?.mappedPortChanged(to: nil)
                        return
                    }
                    self?.sendPortForwardingNotificationIfNeeded(portNumber: portMapping.mappedExternalPort)
                    self?.delegate?.mappedPortChanged(to: portMapping.mappedExternalPort)

                case .failure:
                    self?.sendPortForwardingNotificationErrorIfNeeded()
                    self?.delegate?.mappedPortChanged(to: nil)
                }
            })
    }

    private func sendPortForwardingNotificationIfNeeded(portNumber: UInt16) {
        if AuthorizedFeatureValue<PortForwardingNotifications>().value() == .on {
            DispatchQueue.main.async {
                self.notificationManager.displayPFChange(portNumber: portNumber)
            }
        }
    }

    private func sendPortForwardingNotificationErrorIfNeeded() {
        if AuthorizedFeatureValue<PortForwardingNotifications>().value() == .on {
            DispatchQueue.main.async {
                self.notificationManager.displayPFError()
            }
        }
    }

    private func rateString(for rate: UInt32) -> String {
        switch rate {
        case let rate where rate >= UInt32(pow(1024.0, 3)):
            "\(String(format: "%.1f", Double(rate) / pow(1024.0, 3))) GB/s"
        case let rate where rate >= UInt32(pow(1024.0, 2)):
            "\(String(format: "%.1f", Double(rate) / pow(1024.0, 2))) MB/s"
        case let rate where rate >= 1024:
            "\(String(format: "%.1f", Double(rate) / 1024.0)) KB/s"
        default:
            "\(String(format: "%.1f", Double(rate))) B/s"
        }
    }

    private func formHeaderLabel() -> NSAttributedString {
        if isAuthenticationRequired {
            return "Authentication required".styled(.warning, font: .themeFont(.heading4, bold: true), alignment: .left)
        }
        // Advanced kill switch is actively blocking (zero-peer)
        if case .killSwitchActive = connectionState {
            return Localizable.killSwitchAdvancedBannerTitle.styled(.warning, font: .themeFont(.heading4, bold: true), alignment: .left)
        }
        // A ProTUN peer handover keeps the previous connection's interface up, so a server change never shows the user
        // as exposed. The label names the server the tunnel is moving to.
        if !connectionState.tunnelActive {
            return Localizable.youAreNotProtected.styled(.danger, font: .themeFont(.heading4, bold: true), alignment: .left)
        }

        guard let server = connectedServer else {
            return Localizable.noDescriptionAvailable.styled(font: .themeFont(.heading4), alignment: .left)
        }

        let font = NSFont.themeFont(.heading4)
        if case let .secureCore(entryCountryCode) = server.logical.kind {
            let secureCoreIcon = AppTheme.Icon.locks.asAttachment(style: .normal, size: .square(16), centeredVerticallyForFont: font)
            let entryCountryName = LocalizationUtility.default.countryName(forCode: entryCountryCode) ?? Localizable.unavailable
            let entryCountry = (" " + entryCountryName + " ").styled(.normal, font: font, alignment: .left)
            let doubleArrows = AppTheme.Icon.chevronsRight.asAttachment(style: .normal, size: .square(16), centeredVerticallyForFont: font)
            let exitCountryName = LocalizationUtility.default.countryName(forCode: server.logical.exitCountryCode) ?? Localizable.unavailable
            let exitCountry = (" " + exitCountryName + " ").styled(font: font, alignment: .left)
            return NSAttributedString.concatenate(secureCoreIcon, entryCountry, doubleArrows, exitCountry)
        } else {
            let countryName = LocalizationUtility.default.countryName(forCode: server.logical.exitCountryCode) ?? Localizable.unavailable
            let country = (countryName + " ").styled(font: font, alignment: .left)
            let serverName = server.logical.name.styled(font: font, alignment: .left)
            return NSAttributedString.concatenate(country, serverName)
        }
    }

    private func formIpLabel() -> NSAttributedString {
        if isAuthenticationRequired {
            return "VPN traffic is blocked until you authenticate.".styled(.warning, alignment: .left)
        }
        if case .killSwitchActive = connectionState {
            return Localizable.killSwitchAdvancedBannerMessage.styled(alignment: .left)
        }
        let ip = Localizable.ipValue(getCurrentIp() ?? Localizable.unavailable)
        let attributedString = NSMutableAttributedString(attributedString: ip.styled(alignment: .left))
        let ipRange = (ip as NSString).range(of: getCurrentIp() ?? Localizable.unavailable)
        attributedString.addAttribute(.font, value: NSFont.themeFont(bold: true), range: ipRange)
        return attributedString
    }

    private func getCurrentIp() -> String? {
        if isConnected {
            connectedServer?.endpoint.offsetExitIp
        } else {
            userLocation?.ip
        }
    }

    private func formLoadLabel(short: Bool = false) -> NSAttributedString? {
        guard let server = connectedServer else {
            return nil
        }
        return (short ? "\(server.logical.load)%" : Localizable.serverLoadPercentage(server.logical.load))
            .styled(font: .themeFont(.small), alignment: .right)
    }

    private var connectedServer: Server? {
        connectionState.resolvedServer
    }
}
