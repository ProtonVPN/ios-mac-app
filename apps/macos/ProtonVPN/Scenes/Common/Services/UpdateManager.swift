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

import Foundation
import Sparkle
import LegacyCommon
import Cocoa
import Version

protocol UpdateManagerFactory {
    func makeUpdateManager() -> UpdateManager
}

class UpdateManager: NSObject {
    
    public typealias Factory = UpdateFileSelectorFactory & PropertiesManagerFactory
    private let factory: Factory
    
    private lazy var updateFileSelector: UpdateFileSelector = factory.makeUpdateFileSelector()
    
    // Callback for UI
    public var stateUpdated: (() -> Void)?
    
    private var appSessionManager: AppSessionManager?
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    
    private var updater: SPUStandardUpdaterController?
    private var appcast: SUAppcast?

    public var currentVersion: String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    public var currentBuild: String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
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
    
    public init(_ factory: Factory) {
        self.factory = factory
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(earlyAccessChanged), name: PropertiesManager.earlyAccessNotification, object: nil)
        
        suDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss ZZ"
        
        updater = SPUStandardUpdaterController(updaterDelegate: self, userDriverDelegate: nil)
    }
        
    @objc private func earlyAccessChanged(_ notification: NSNotification) {
        turnOnEarlyAccess((notification.object as? Bool) ?? false)
    }
    
    private func turnOnEarlyAccess(_ earlyAccess: Bool) {
        if earlyAccess {
            checkForUpdates(nil, silently: false)
        }
    }
    
    func checkForUpdates(_ appSessionManager: AppSessionManager?, silently: Bool) {
        self.appSessionManager = appSessionManager
        
        propertiesManager.rememberLoginAfterUpdate = false
        
        NSApp.windows.forEach { (window) in
            if window.title == "Software Update" {
                window.makeKeyAndOrderFront(self)
                window.level = .floating
                return
            }
        }
        
        silently ? updater?.updater.checkForUpdatesInBackground() : updater?.checkForUpdates(self)
    }
    
    func startUpdate() {
        updater?.checkForUpdates(self)
    }
    
    // MARK: - Private data
        
    private var currentAppCastItem: SUAppcastItem? {
        guard let items = appcast?.items else {
            return nil
        }
        let currentVersion = self.currentVersion
        for item in items where item.displayVersionString.elementsEqual(currentVersion ?? "wrong-string") {
            return item
        }
        return nil
    }
    
    private var newestAppCastItem: SUAppcastItem? {
        appcast?.items.first {
            $0.minimumOperatingSystemVersionIsOK && $0.maximumOperatingSystemVersionIsOK &&
            ($0.channel == nil || $0.channel == channel)
        }
    }
    
    private let suDateFormatter: DateFormatter = DateFormatter()
    
}

extension UpdateManager: SPUUpdaterDelegate {
    func versionComparator(for updater: SPUUpdater) -> (any SUVersionComparison)? {
        return CustomVersionComparator.shared
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        if let sessionManager = appSessionManager, sessionManager.loggedIn {
            propertiesManager.rememberLoginAfterUpdate = true
        }
    }
    
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        self.appcast = appcast
        stateUpdated?()
    }
    
    func feedURLString(for updater: SPUUpdater) -> String? {
        let url = updateFileSelector.updateFileUrl
        log.info("FeedURL is \(url)", category: .appUpdate)
        return url
    }
    
    func updaterMayCheck(forUpdates updater: SPUUpdater) -> Bool {
        guard !propertiesManager.blockUpdatePrompt else {
            return false
        }
        return true
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        guard let channel else { return [] }
        return [channel]
    }
}

extension UpdateManager: UpdateChecker {
    func isUpdateAvailable(_ callback: (Bool) -> Void) {
        guard let item = newestAppCastItem, let currentBuild = currentBuild else {
            callback(false)
            return
        }

        callback(CustomVersionComparator.shared.compareVersion(currentBuild, toVersion: item.versionString) == .orderedAscending)
    }
}

/// Compare two versions in a custom fashion.
///
/// Old build numbers used to look like simple timestamps, like `2403121548`, which was simply the time the app was
/// built. New build numbers include a pipeline identifier on the front, plus a date timestamp that corresponds to
/// the timestamp of the commit on `HEAD` when the app was built. We need to hit Sparkle on the head hard enough so
/// that it thinks that the `123456.2403121548` version is actually *greater* than a build number like `2402121213`.
/// This has to stay here forever as a defense-in-depth measure against downgrade attacks. Computing is fun!
final class CustomVersionComparator: SUVersionComparison {
    static let shared = CustomVersionComparator()
    static let standard = SUStandardVersionComparator()

    enum ContainsPipeline: String {
        case yes = "PipelineId"
        case no = "NoPipelineId"

        init?(_ version: Version) {
            guard let id = version.buildMetadataIdentifiers.first else { return nil }
            guard let value = Self(rawValue: id) else { return nil }
            self = value
        }
    }

    func convertToSemVer(_ buildNumber: String) -> Version? {
        let components = buildNumber.split(separator: ".")
        if components.count == 1, let buildNumberInt = Int(components[0]) {
            return .init(buildNumberInt, 0, 0, build: [ContainsPipeline.no.rawValue])
        } else if components.count == 2,
                  let pipelineId = Int(components[0]),
                  let buildNumberInt = Int(components[1]) {
            return .init(pipelineId, buildNumberInt, 0, build: [ContainsPipeline.yes.rawValue])
        } else {
            guard let version = Version(buildNumber) else { return nil }
            // If we don't recognize this build number, strip out any build metadata identifiers to avoid potential
            // attackers from injecting their own and affecting the "ContainsPipeline" logic below.
            return Version(version.major, version.minor, version.patch, pre: version.prereleaseIdentifiers)
        }
    }

    func compareVersion(_ versionA: String, toVersion versionB: String) -> ComparisonResult {
        guard let parsedVersionA = convertToSemVer(versionA),
              let parsedVersionB = convertToSemVer(versionB) else {
            return Self.standard.compareVersion(versionA, toVersion: versionB)
        }

        switch (ContainsPipeline(parsedVersionA), ContainsPipeline(parsedVersionB)) {
        case (.yes, .no):
            return parsedVersionA.minor < parsedVersionB.major ? .orderedAscending : .orderedDescending
        case (.no, .yes):
            return parsedVersionA.major < parsedVersionB.minor ? .orderedAscending : .orderedDescending
        default:
            break
        }

        return Self.standard.compareVersion(versionA, toVersion: versionB)
    }
}
