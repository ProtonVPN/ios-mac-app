//
//  UpdateManager.swift
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
import Foundation

import Dependencies
import Sparkle
import Version

import Domain
import LegacyCommon

protocol UpdateManagerFactory {
    func makeUpdateManager() -> UpdateManager
}

final class UpdateManager: NSObject {
    private static let updateChillInterval: TimeInterval = .hours(1)

    // Callback for UI
    public var stateUpdated: (() -> Void)?

    private var appSessionManager: AppSessionManager?
    @Dependency(\.propertiesManager) private var propertiesManager

    private var updater: SPUStandardUpdaterController?
    private var appcast: SUAppcast?

    private var lastUpdateDismissal: Date?
    private var chillOut: Bool {
        if let lastUpdateDismissal, Date().timeIntervalSince(lastUpdateDismissal) < Self.updateChillInterval {
            return true
        }

        return false
    }

    public var feedURLString: String? {
        Bundle.main.infoDictionary?["SUFeedURL"] as? String
    }

    public var currentVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    public var currentBuild: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    public var channel: String? {
        if propertiesManager.earlyAccess {
            return "beta"
        }

        return nil // default channel
    }

    public var currentVersionReleaseDate: Date? {
        guard let item = currentAppCastItem, let dateString = item.dateString else {
            return nil
        }
        return suDateFormatter.date(from: dateString)
    }

    public var releaseNotes: [String]? {
        guard let items = appcast?.items else {
            return nil
        }

        return items.compactMap {
            let item = $0 as SUAppcastItem
            guard item.channel == nil || item.channel == channel else { return nil }

            return item.itemDescription ?? ""
        }
    }

    override public init() {
        super.init()

        AppEvent.earlyAccess.subscribe(self, selector: #selector(earlyAccessChanged))

        suDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss ZZ"

        self.updater = SPUStandardUpdaterController(updaterDelegate: self, userDriverDelegate: nil)
    }

    @objc
    private func earlyAccessChanged(_ notification: NSNotification) {
        turnOnEarlyAccess((notification.object as? Bool) ?? false)
    }

    private func turnOnEarlyAccess(_ earlyAccess: Bool) {
        lastUpdateDismissal = nil

        if earlyAccess {
            checkForUpdates(nil, userInitiated: true)
        }
    }

    func checkForUpdates(_ appSessionManager: AppSessionManager?, userInitiated: Bool) {
        self.appSessionManager = appSessionManager

        propertiesManager.rememberLoginAfterUpdate = false

        for window in NSApp.windows {
            if window.title == "Software Update" {
                window.makeKeyAndOrderFront(self)
                window.level = .floating
                continue
            }
        }

        guard userInitiated else {
            updater?.updater.checkForUpdatesInBackground()
            return
        }

        updater?.checkForUpdates(self)
    }

    func startUpdate() {
        updater?.checkForUpdates(self)
    }

    // MARK: - Private data

    private var currentAppCastItem: SUAppcastItem? {
        guard let items = appcast?.items else {
            return nil
        }
        let currentVersion = currentVersion
        for item in items where item.displayVersionString.elementsEqual(currentVersion ?? "wrong-string") {
            return item
        }
        return nil
    }

    private var newestAppCastItem: SUAppcastItem? {
        appcast?.items.first {
            $0.channel == nil || $0.channel == channel
        }
    }

    private var newestAppCastItemThatSupportsThisOS: SUAppcastItem? {
        appcast?.items.first {
            $0.minimumOperatingSystemVersionIsOK && $0.maximumOperatingSystemVersionIsOK &&
                ($0.channel == nil || $0.channel == channel)
        }
    }

    private let suDateFormatter: DateFormatter = .init()
}

extension UpdateManager: SPUUpdaterDelegate {
    func updaterWillRelaunchApplication(_: SPUUpdater) {
        if let sessionManager = appSessionManager, sessionManager.loggedIn {
            propertiesManager.rememberLoginAfterUpdate = true
        }
    }

    func updater(_: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        self.appcast = appcast
        stateUpdated?()
    }

    func updater(_: SPUUpdater, userDidMake choice: SPUUserUpdateChoice, forUpdate _: SUAppcastItem, state _: SPUUserUpdateState) {
        switch choice {
        case .dismiss, .skip:
            lastUpdateDismissal = Date()
        case .install:
            break
        @unknown default:
            break
        }
    }

    func updater(_: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        switch updateCheck {
        case .updatesInBackground:
            guard !chillOut else {
                throw UpdateCheckError.userAlreadyDismissedUpdate
            }
        case .updates, .updateInformation:
            break
        @unknown default:
            break
        }
    }

    func feedURLString(for _: SPUUpdater) -> String? {
        feedURLString
    }

    func updaterMayCheck(forUpdates _: SPUUpdater) -> Bool {
        guard !propertiesManager.blockUpdatePrompt else {
            return false
        }
        return true
    }

    func allowedChannels(for _: SPUUpdater) -> Set<String> {
        guard let channel else { return [] }
        return [channel]
    }
}

extension UpdateManager: UpdateChecker {
    enum UpdateCheckError: String, Error, CustomStringConvertible {
        case notReady = "No appcast item has appeared yet."
        case invalidMinimumSystemVersion = "Invalid or unrecognized minimum system version."
        case missingMinimumSystemVersion = "No minimum system version specified in update item."
        case userAlreadyDismissedUpdate = "User previously dismissed an update within the cooldown interval."

        var description: String { rawValue }
    }

    func isUpdateAvailable() async -> Bool {
        guard let item = newestAppCastItemThatSupportsThisOS,
              let currentBuild else {
            return false
        }

        return SUStandardVersionComparator.default.compareVersion(currentBuild, toVersion: item.versionString) == .orderedAscending
    }

    /// Check if the latest app supports the current running OS version.
    func minimumVersionRequiredByNextUpdate() async -> OperatingSystemVersion {
        do {
            guard let item = newestAppCastItem else { throw UpdateCheckError.notReady }

            // If no minimum system version is specified, assume we're included.
            guard let minimumOSVersionString = item.minimumSystemVersion else {
                throw UpdateCheckError.missingMinimumSystemVersion
            }

            guard let minimumOSVersion = OperatingSystemVersion(osVersionString: minimumOSVersionString) else {
                throw UpdateCheckError.invalidMinimumSystemVersion
            }

            return minimumOSVersion
        } catch {
            log.error("Couldn't check minimum version required by next update", metadata: ["error": "\(error)"])
            return ProcessInfo.processInfo.operatingSystemVersion
        }
    }
}
