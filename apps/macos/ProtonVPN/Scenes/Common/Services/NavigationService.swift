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
import Network
import os

import ComposableArchitecture

import PMLogger

import CommonNetworking
import LegacyCommon
import VPNShared

import Domain
import Ergonomics

protocol NavigationServiceFactory {
    func makeNavigationService() -> NavigationService
}

class NavigationService {
    typealias Factory = AppSessionManagerFactory
        & AppStateManagerFactory
        & AuthKeychainHandleFactory
        & CoreAlertServiceFactory
        & HelpMenuViewModelFactory
        & LogFileManagerFactory
        & NavigationServiceFactory
        & NetShieldPropertyProviderFactory
        & NetworkingFactory
        & ProfileManagerFactory
        & PropertiesManagerFactory
        & ProtonReachabilityCheckerFactory
        & ReportBugViewModelFactory
        & SafeModePropertyProviderFactory
        & SystemExtensionManagerFactory
        & TelemetrySettingsFactory
        & UpdateManagerFactory
        & VpnApiServiceFactory
        & VpnGatewayFactory
        & VpnKeychainFactory
        & VpnManagerFactory
        & VpnProtocolChangeManagerFactory
        & VpnStateConfigurationFactory
        & WindowServiceFactory
    private let factory: Factory

    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var vpnApiService: VpnApiService = factory.makeVpnApiService()
    lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var updateManager: UpdateManager = factory.makeUpdateManager()
    private lazy var authKeychain: AuthKeychainHandle = factory.makeAuthKeychainHandle()
    lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var systemExtensionManager: SystemExtensionManager = factory.makeSystemExtensionManager()

    var appHasPresented = false
    var isSystemTeardown = false

    private var notificationTokens: [NotificationToken] = []

    // Add a flag and interval to suppress duplicate reconnection after wake
    private var didHandleWake = false
    private let wakeSuppressionInterval: TimeInterval = 3 // seconds

    init(_ factory: Factory) { // be careful not to initialize anything that could create a cycle if that object were to use the NavigationService (e.g. AppStateManager)
        self.factory = factory
    }

    @MainActor
    func launched() async {
        notificationTokens.append(
            NotificationCenter.default.addObserver(
                for: SessionChanged.self,
                object: appSessionManager,
                handler: sessionChanged
            )
        )
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
        vpnGateway.disconnect()
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

    private func autoConnectIfEnabled() {
        guard vpnGateway.connection == .disconnected else {
            return
        }

        guard let username = authKeychain.username else {
            return
        }

        guard propertiesManager.getAutoConnect(for: username).enabled else {
            return
        }

        vpnGateway.autoConnect()
    }

    @objc
    func handleWake() {
        log.debug("User device has woken up", category: .app)
        didHandleWake = true
        autoConnectIfEnabled()
        // Reset the flag after a short interval
        DispatchQueue.main.asyncAfter(deadline: .now() + wakeSuppressionInterval) {
            self.didHandleWake = false
        }
    }

    #if REDESIGN
        var sendAction: AppReducer.ActionSender?
    #endif

    private func sessionChanged(data: SessionChanged.T) {
        windowService.closeActiveWindows(except: [SysexGuideWindowController.self])

        switch data {
        case let .established(vpnGateway):
            if appSessionManager.sessionStatus != .established {
                log.error("Expected session to be established when receiving gateway")
            }
            self.vpnGateway = vpnGateway
            switch appStateManager.state {
            case .disconnected, .aborted:
                if let username = authKeychain.username, propertiesManager.getAutoConnect(for: username).enabled {
                    vpnGateway.autoConnect()
                }
            default:
                break
            }

            if appHasPresented {
                showSidebar()
            }
        case let .lost(loginError):
            showLogIn(initialError: loginError)
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

    private func showSidebar() {
        appHasPresented = true
        #if REDESIGN
            sendAction?(.logIn(.init()))
        #else
            windowService.showSidebar(appStateManager: appStateManager, vpnGateway: vpnGateway)
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
        let viewModel = factory.makeReportBugViewModel()
        windowService.openReportBugWindow(viewModel: viewModel, alertService: alertService)
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

    func checkForUpdates() {
        updateManager.checkForUpdates(appSessionManager, userInitiated: true)
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
        let logFileManager = factory.makeLogFileManager()
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
            accountViewModel: AccountViewModel(
                vpnKeychain: factory.makeVpnKeychain(),
                propertiesManager: factory.makePropertiesManager(),
                authKeychain: factory.makeAuthKeychainHandle()
            )
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

        windowService.openProfilesWindow(viewModel: ProfilesContainerViewModel(initialTab: initialTab, vpnGateway: vpnGateway, alertService: alertService, vpnKeychain: vpnKeychain))
    }

    @objc
    private func tearDown(_: Notification) {
        log.debug("System user is being logged out, or app data is being cleared", category: .os)
        isSystemTeardown = true
    }

    private func openRequiredWindow() {
        if !windowService.bringWindowsToForeground() {
            if appSessionManager.sessionStatus == .established {
                showSidebar()
            } else {
                showLogIn()
            }

            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        // Addresses bug where menu bar becomes active when switching from .accessory to .regular mode
        if (NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.activate(options: []))! {
            dispatch_after_delay(0.1, queue: .main) {
                NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
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

        guard vpnGateway.connection != .disconnected else {
            return .terminateNow
        }

        vpnGateway.disconnect {
            DispatchQueue.main.async {
                self.isSystemTeardown = false
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }

        return .terminateLater
    }
}
