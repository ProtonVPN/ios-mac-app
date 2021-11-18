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
import vpncore

protocol UpdateManagerFactory {
    func makeUpdateManager() -> UpdateManager
}

class UpdateManager: NSObject {
    
    public typealias Factory = UpdateFileSelectorFactory
    private let factory: Factory
    
    private lazy var updateFileSelector: UpdateFileSelector = factory.makeUpdateFileSelector()
    
    // Callback for UI
    public var stateUpdated: (() -> Void)?
    
    private var appSessionManager: AppSessionManager?
    private let propertiesManager = PropertiesManager()
    
    private var updater: SPUStandardUpdaterController?
    private var appcast: SUAppcast?

    public var currentVersion: String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    public var currentBuild: String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
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
        return items.map { ($0 as SUAppcastItem).itemDescription ?? "" }
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
        
        silently ? updater?.updater?.checkForUpdatesInBackground() : updater?.checkForUpdates(self)
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
        for item in items where item.displayVersionString?.elementsEqual(currentVersion ?? "wrong-string") ?? false {
            return item
        }
        return nil
    }
    
    private let suDateFormatter: DateFormatter = DateFormatter()
    
}

extension UpdateManager: SPUUpdaterDelegate {
    
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
    
}
