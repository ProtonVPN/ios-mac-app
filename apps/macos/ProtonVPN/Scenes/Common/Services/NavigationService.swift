//
//  NavigationService.swift
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
import Combine
import CommonNetworking
import ComposableArchitecture
import Connection
import ConnectionInventory
import Domain
import Ergonomics
import Foundation
import LegacyCommon
import Network
import os
import PMLogger
import Sharing
import VPNAppCore
import VPNShared

protocol NavigationServiceFactory {
    func makeNavigationService() -> NavigationService
}

class NavigationService {
    typealias Factory = AppSessionManagerFactory
        & HelpMenuViewModelFactory
        & NavigationServiceFactory
        & ProtonReachabilityCheckerFactory
        & VpnProtocolChangeManagerFactory
    private let factory: Factory
    lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()

    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.credentialsProvider) private var credentials
    @SharedReader(.connectionState) private var connectionState: ConnectionState
    @SharedReader(.sessionStatus) private var sessionStatus: SessionStatus
    @SharedReader(.sessionLogoutReason) private var sessionLogoutReason: String?
    @Dependency(\.windowService) private var windowService
    @Dependency(\.authKeychain) private var authKeychain

    var appHasPresented = false
    var isSystemTeardown = false

    private var cancellables = Set<AnyCancellable>()

    // Add a flag and interval to suppress duplicate reconnection after wake
    private var didHandleWake = false
    private let wakeAutoConnectDelayInterval: TimeInterval = 2.5 // seconds
    private let wakeSuppressionInterval: TimeInterval = 5 // seconds

    init(_ factory: Factory) {
        self.factory = factory
    }

    @MainActor
    func launched() async {
        $sessionStatus.publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.sessionChanged(status) }
            .store(in: &cancellables)
        AppEvent.clearingApplicationData.subscribe(self, selector: #selector(tearDown(_:)))

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(tearDown(_:)),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(sessionSwitchedOut(_:)),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(sessionBecameActive(_:)),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        if propertiesManager.startMinimized {
            await attemptSilentLogIn()
        } else {
            showLogIn()
        }
    }

    @objc
    private func sessionSwitchedOut(_: NSNotification) {
        log.debug("User session did resign active", category: .app)
        connectionCommandClient.send(.disconnect(.exit))
    }

    @objc
    private func sessionBecameActive(_: NSNotification) {
        log.debug("User session did become active", category: .app)
        // Only auto-connect if not just handled by wake
        guard !didHandleWake else {
            log.debug("Suppressed autoConnectIfEnabled due to recent wake", category: .app)
            return
        }
        autoConnectIfEnabled()
    }

    /// Whether the conditions are met to start an auto-connect:
    ///   * VPN is fully disconnected,
    ///   * a user is logged in,
    ///   * that user has auto-connect enabled in their settings.
    private var shouldAutoConnect: Bool {
        switch connectionState {
        case .connected:
            log.debug("Skipping auto-connect: already connected", category: .app)
            return false
        case .connecting:
            log.debug("Skipping auto-connect: already connecting", category: .app)
            return false
        case .resolving:
            log.debug("Skipping auto-connect: connection state still unresolved", category: .app)
            return false
        case .disconnecting:
            log.debug("Skipping auto-connect: connection state is \(connectionState)", category: .app)
            return false
        case .disconnected:
            break
        }

        guard let username = authKeychain.username else {
            log.debug("Skipping auto-connect: no username in keychain", category: .app)
            return false
        }

        guard propertiesManager.getAutoConnect(for: username).enabled else {
            log.debug("Skipping auto-connect: auto-connect disabled for user", category: .app)
            return false
        }

        return true
    }

    private func autoConnectIfEnabled() {
        Task { @MainActor [weak self] in
            await self?.waitForConnectionStateToResolve()
            guard let self, shouldAutoConnect else { return }
            log.info("Initiating auto-connect", category: .app)
            triggerAutoConnect()
        }
    }

    private static let checkInterval: Duration = .milliseconds(200)
    private static let timeOut: Duration = .seconds(10)

    private func waitForConnectionStateToResolve() async {
        guard connectionState.is(\.resolving) else { return }
        log.debug("Auto-connect deferred while connection state resolves", category: .app)
        do {
            try await $connectionState.when(
                willMatch: { !$0.is(\.resolving) },
                every: Self.checkInterval,
                deadline: Self.timeOut,
                operation: { _ in }
            )
        } catch {
            log.warning(
                "Connection state did not leave .resolving in time; auto-connect proceeds with current state",
                category: .app
            )
        }
    }

    @objc
    func handleWake() {
        log.debug("User device has woken up", category: .app)
        didHandleWake = true

        DispatchQueue.main.asyncAfter(deadline: .now() + wakeAutoConnectDelayInterval) {
            log.debug("Attempting auto-connect after wake delay", category: .app)
            self.autoConnectIfEnabled()
        }

        // Address sessionBecameActive duplicate connection attempts
        DispatchQueue.main.asyncAfter(deadline: .now() + wakeSuppressionInterval) {
            self.didHandleWake = false
            log.debug("Wake suppression window ended", category: .app)
        }
    }

    #if REDESIGN
        var sendAction: AppReducer.ActionSender?
    #endif

    private func sessionChanged(_ status: SessionStatus) {
        windowService.closeActiveWindows(except: [SysexGuideWindowController.self])

        switch status {
        case .established:
            autoConnectIfEnabled()

            if appHasPresented {
                showSidebar()
            }
        case .notEstablished:
            showLogIn(initialError: sessionLogoutReason)
        case .undetermined:
            break
        }
    }

    func loginViewModel() -> LoginViewModel {
        LoginViewModel(factory: factory)
    }

    private func showLogIn(initialError: String? = nil) {
        appHasPresented = true
        #if REDESIGN
            sendAction?(.showLogin(.showError(initialError: initialError)))
        #else
            let viewModel = loginViewModel()
            viewModel.initialError = initialError
            windowService.showLogin(viewModel: viewModel)
            NSApp.activate(ignoringOtherApps: true)
        #endif
    }

    private func attemptSilentLogIn() async {
        let viewModel = LoginViewModel(factory: factory)
        await viewModel.logInSilently()
    }

    private func triggerAutoConnect() {
        @Dependency(\.profileManager) var profileManager
        if let profile = profileManager.autoConnectProfile() {
            let spec = profile.connectionSpec(trigger: .auto)
            connectionCommandClient.send(.connect(spec, profile.connectionProtocol, .auto))
            return
        }

        @Shared(.secureCoreToggle) var secureCoreToggle
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: secureCoreToggle,
            connectedExitCountryCode: nil,
            isFreeTier: credentials.tier.isFreeTier
        )
        connectionCommandClient.send(.connect(spec, nil, .auto))
    }

    private func showSidebar() {
        appHasPresented = true
        #if REDESIGN
            sendAction?(.logIn(.init()))
        #else
            windowService.showSidebar()
        #endif
    }

    func handleSilentLoginFailure() {
        showLogIn()
    }

    func showPlutonium() {
        windowService.closeIfPresent(windowController: PlutoniumWindowController.self)
        windowService.openPlutoniumWindow()
    }

    func showReportBug() {
        windowService.closeIfPresent(windowController: ReportBugWindowController.self)
        windowService.openReportBugWindow()
    }
}

// MARK: - Menu controllers extension

extension NavigationService {
    func openAbout(factory: AboutViewController.Factory) {
        guard !windowService.showIfPresent(windowController: AboutWindowController.self) else { return }
        windowService.openAbout(factory: factory)
    }

    func openAcknowledgements() {
        guard !windowService.showIfPresent(windowController: AcknowledgementsWindowController.self) else { return }
        windowService.openAcknowledgements()
    }

    // If the user is manually showing the logs in Finder to share with someone, make sure that the log file
    // contains the debug information for the device, to the best of our ability.
    func ensureLogsContainDebugInfo(at url: URL) {
        guard let fileHandle = FileHandle(forUpdatingAtPath: url.path(percentEncoded: false)) else {
            return
        }

        let filePrefix = "==> "
        guard let prefixData = try? fileHandle.read(upToCount: filePrefix.count) else {
            return
        }

        if let string = String(data: prefixData, encoding: .ascii), string == filePrefix {
            return
        }

        guard let remainingData = try? fileHandle.readToEnd() else {
            return
        }

        let debugInfoString = filePrefix + FileLogContent.debugInfoString + "\n"
        guard let infoStringData = debugInfoString.data(using: .utf8) else {
            return
        }

        do {
            try fileHandle.seek(toOffset: 0)
        } catch {
            return
        }

        try? fileHandle.write(contentsOf: infoStringData + prefixData + remainingData)
    }

    func openLogsFolder(filename: String? = nil) {
        @Dependency(\.logFileManager) var logFileManager
        let filename = filename ?? AppConstants.Filenames.appLogFilename
        let fileUrl = logFileManager.getFileUrl(named: filename)
        ensureLogsContainDebugInfo(at: fileUrl)

        NSWorkspace.shared.activateFileViewerSelecting([fileUrl])
    }

    func openSettings(to tab: SettingsTab) {
        windowService.closeIfPresent(windowController: SettingsWindowController.self)

        windowService.openSettingsWindow(
            viewModel: SettingsContainerViewModel(factory: factory),
            tabBarViewModel: SettingsTabBarViewModel(initialTab: tab),
            accountViewModel: AccountViewModel()
        )
    }

    func logOutRequested() {
        appSessionManager.logOut()
    }

    func showApplication() {
        appHasPresented = true
        openRequiredWindow()
    }

    func openProfiles(_ initialTab: ProfilesTab) {
        guard !windowService.showIfPresent(windowController: ProfilesWindowController.self) else { return }

        windowService.openProfilesWindow(viewModel: ProfilesContainerViewModel(initialTab: initialTab))
    }

    @objc
    private func tearDown(_: Notification) {
        log.debug("System user is being logged out, or app data is being cleared", category: .os)
        isSystemTeardown = true
    }

    private func openRequiredWindow() {
        if !windowService.bringWindowsToForeground() {
            if sessionStatus == .established {
                showSidebar()
            } else {
                showLogIn()
            }

            NSRunningApplication.current.activate(options: [.activateAllWindows])
        }

        // Addresses bug where menu bar becomes active when switching from .accessory to .regular mode
        if NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.activate(options: []) == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSRunningApplication.current.activate(options: [.activateAllWindows])
            }
        }
    }
}

// MARK: - AppDelegate extension

extension NavigationService {
    func handleApplicationReopen(hasVisibleWindows _: Bool) -> Bool {
        appHasPresented = true

        // Don't ever dismiss the system extension tour, Sparkle will use this function when presenting the alert,
        // and we wouldn't want random update prompts to dismiss the tour unnecessarily
        windowService.closeActiveWindows(except: [SysexGuideWindowController.self])
        openRequiredWindow()

        return false
    }

    func handleApplicationShouldTerminate() -> NSApplication.TerminateReply {
        guard isSystemTeardown else {
            appSessionManager.replyToApplicationShouldTerminate()
            return .terminateLater
        }

        // Do not show disconnect modal, because user asked for macOS logOff/shutdown
        // Make sure to disconnect the gateway and disable the firewall before logOff/shutdown

        if connectionState.is(\.disconnected) {
            return .terminateNow
        }

        connectionCommandClient.send(.disconnect(.exit, completion: { [weak self] in
            guard let self else { return }
            isSystemTeardown = false
            NSApp.reply(toApplicationShouldTerminate: true)
        }))

        return .terminateLater
    }
}
