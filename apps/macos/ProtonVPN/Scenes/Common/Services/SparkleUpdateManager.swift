//
//  SparkleUpdateManager.swift
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
import Dependencies
import Ergonomics
import Foundation
import PMLogger
import Sharing
import Sparkle
import VPNAppCore

final class SparkleUpdateManager: NSObject {
    private static let updateChillInterval: TimeInterval = .hours(1)

    /// Fires when update state changes (e.g. the appcast finishes loading), exposed via ``stateUpdates()``.
    private let stateUpdateSubject = PassthroughSubject<Void, Never>()

    @Dependency(\.appInfo) private var appInfo

    /// Beta-channel opt-in. Toggled from Settings
    @SharedReader(.earlyAccess) private var earlyAccess

    #if DEBUG
        /// When set, suppresses update prompts (used in UI tests)
        @SharedReader(.blockUpdatePrompt) private var blockUpdatePrompt
    #endif

    private var updater: SPUStandardUpdaterController?
    private var appcast: SUAppcast?
    private var earlyAccessObservation: AnyCancellable?

    private var lastUpdateDismissal: Date?

    /// Set to `true` immediately before Sparkle relaunches the app to apply an update, so termination
    /// proceeds without the quit confirmation prompt
    private(set) var isRelaunchingForUpdate = false

    private var chillOut: Bool {
        if let lastUpdateDismissal, Date().timeIntervalSince(lastUpdateDismissal) < Self.updateChillInterval {
            return true
        }

        return false
    }

    var feedURLString: String? {
        appInfo.bundleInfoDictionary()["SUFeedURL"] as? String
    }

    private var currentVersion: String? {
        appInfo.bundleShortVersion
    }

    private var currentBuild: String? {
        appInfo.bundleVersion
    }

    var channel: String? {
        if earlyAccess {
            return "beta"
        }

        return nil // default channel
    }

    var currentVersionReleaseDate: Date? {
        guard let item = currentAppCastItem, let dateString = item.dateString else {
            return nil
        }
        return suDateFormatter.date(from: dateString)
    }

    var releaseNotes: [String]? {
        guard let items = appcast?.items else {
            return nil
        }

        return items.compactMap {
            let item = $0 as SUAppcastItem
            guard item.channel == nil || item.channel == channel else { return nil }

            return item.itemDescription ?? ""
        }
    }

    override init() {
        super.init()

        self.earlyAccessObservation = $earlyAccess.publisher
            .dropFirst()
            .sink { [weak self] earlyAccess in
                self?.turnOnEarlyAccess(earlyAccess)
            }

        suDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss ZZ"

        self.updater = SPUStandardUpdaterController(updaterDelegate: self, userDriverDelegate: nil)
    }

    private func turnOnEarlyAccess(_ earlyAccess: Bool) {
        lastUpdateDismissal = nil

        if earlyAccess {
            checkForUpdates(userInitiated: true)
        }
    }

    func checkForUpdates(userInitiated: Bool) {
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

    /// A publisher that emits each time update state changes (e.g. the appcast finishes loading).
    func stateUpdates() -> AnyPublisher<Void, Never> {
        stateUpdateSubject.eraseToAnyPublisher()
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

extension SparkleUpdateManager: SPUUpdaterDelegate {
    // Allows us to leave the VPN connected while relaunching for an update.
    func updaterWillRelaunchApplication(_: SPUUpdater) {
        isRelaunchingForUpdate = true
    }

    func updater(_: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        self.appcast = appcast
        stateUpdateSubject.send()
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
        #if DEBUG
            guard !blockUpdatePrompt else {
                return false
            }
        #endif
        return true
    }

    func allowedChannels(for _: SPUUpdater) -> Set<String> {
        guard let channel else { return [] }
        return [channel]
    }
}

extension SparkleUpdateManager {
    enum UpdateCheckError: String, Error, CustomStringConvertible {
        case notReady = "No appcast item has appeared yet."
        case invalidMinimumSystemVersion = "Invalid or unrecognized minimum system version."
        case missingMinimumSystemVersion = "No minimum system version specified in update item."
        case userAlreadyDismissedUpdate = "User previously dismissed an update within the cooldown interval."

        var description: String {
            rawValue
        }
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

extension UpdateManager: @retroactive DependencyKey {
    public static let liveValue: UpdateManager = {
        let manager = SparkleUpdateManager()
        return UpdateManager(
            isRelaunchingForUpdate: { manager.isRelaunchingForUpdate },
            isUpdateAvailable: { await manager.isUpdateAvailable() },
            minimumVersionRequiredByNextUpdate: { await manager.minimumVersionRequiredByNextUpdate() },
            startUpdate: { manager.startUpdate() },
            checkForUpdates: { manager.checkForUpdates(userInitiated: $0) },
            currentVersionReleaseDate: { manager.currentVersionReleaseDate },
            releaseNotes: { manager.releaseNotes },
            stateUpdates: { manager.stateUpdates() }
        )
    }()
}
