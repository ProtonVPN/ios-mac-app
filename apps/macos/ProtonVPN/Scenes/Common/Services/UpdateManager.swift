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

protocol UpdateManagerFactory {
    func makeUpdateManager() -> UpdateManager
}

final class UpdateManager: NSObject {

    typealias Factory = UpdateFileSelectorFactory & PropertiesManagerFactory
    private let factory: Factory
    
    private lazy var updateFileSelector: UpdateFileSelector = factory.makeUpdateFileSelector()
    
    // Callback for UI
    public var stateUpdated: (() -> Void)?
    
    private var appSessionManager: AppSessionManager?
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    
    private var updater: SPUStandardUpdaterController?
    private var appcast: SUAppcast?

    var currentVersion: String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    var currentBuild: String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
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
        return items.map { ($0 as SUAppcastItem).itemDescription ?? "" }
    }
    
    init(_ factory: Factory) {
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
            $0.minimumOperatingSystemVersionIsOK && $0.maximumOperatingSystemVersionIsOK
        }
    }
    
    private let suDateFormatter: DateFormatter = DateFormatter()
    
}

extension UpdateManager: SPUUpdaterDelegate {
    func bestValidUpdate(in appcast: SUAppcast, for updater: SPUUpdater) -> SUAppcastItem? {
        appcast.items.first {
            $0.minimumOperatingSystemVersionIsOK && $0.maximumOperatingSystemVersionIsOK
        }
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
}

extension UpdateManager: UpdateChecker {
    
    func isUpdateAvailable(_ callback: (Bool) -> Void) {
        guard let item = newestAppCastItem, let currentBuild = currentBuild else {
            callback(false)
            return
        }
        // Using `SUStandardVersionComparator` from Sparkle lib here, so result will be exactly the same as during the update process.
        callback(SUStandardVersionComparator().compareVersion(currentBuild, toVersion: item.versionString) == .orderedAscending)
    }
    
}
