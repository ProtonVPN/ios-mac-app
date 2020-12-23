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

class UpdateManager: NSObject {
    
    // Static constants
    static let shared = UpdateManager()
    
    // Callback for UI
    public var stateUpdated: (() -> Void)?
    
    private let standardFeedURL: URL! = URL(string: "https://protonvpn.com/download/macos-update2.xml")
    
    private let earlyAccessString = "early-access"
    private var earlyAccessFeedURL: URL! {
        return URL(string: "https://protonvpn.com/download/macos-" + earlyAccessString + "-update2.xml")
    }
    
    private var appSessionManager: AppSessionManager?
    private let propertiesManager = PropertiesManager()
    
    private var updater: SUUpdater
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
        guard let items = appcast?.items as? [SUAppcastItem] else {
            return nil
        }
        return items.map { ($0 as SUAppcastItem).itemDescription ?? "" }
    }
    
    override private init() {
        updater = SUUpdater.shared()

        super.init()
        
        // Update feedURL if it is set to anything other than the currently available feedURLs
        if !(updater.feedURL == standardFeedURL || updater.feedURL == earlyAccessFeedURL) {
            if updater.feedURL.absoluteString.contains(earlyAccessString) {
                updater.feedURL = earlyAccessFeedURL
                PMLog.D("Updated feedURL to \(earlyAccessFeedURL.absoluteString)")
            } else {
                updater.feedURL = standardFeedURL
                PMLog.D("Updated feedURL to \(standardFeedURL.absoluteString)")
            }
        }
        
        suDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss ZZ"
        
        updater.delegate = self
    }
    
    func turnOnEarlyAccess(_ earlyAccess: Bool) {
        updater.feedURL = earlyAccess ? earlyAccessFeedURL : standardFeedURL
        
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
        
        silently ? updater.checkForUpdatesInBackground() : updater.checkForUpdates(self)
    }
    
    func startUpdate() {
        updater.installUpdatesIfAvailable()
    }
    
    // MARK: - Private data
        
    private var currentAppCastItem: SUAppcastItem? {
        guard let items = appcast?.items as? [SUAppcastItem] else {
            return nil
        }
        let currentVersion = self.currentVersion
        for item in items where item.displayVersionString.elementsEqual(currentVersion ?? "wrong-string") {
            return item
        }
        return nil
    }
    
    private let suDateFormatter: DateFormatter = DateFormatter()
    
}

extension UpdateManager: SUUpdaterDelegate {

    func updaterWillRelaunchApplication(_ updater: SUUpdater) {
        if let sessionManager = appSessionManager, sessionManager.loggedIn {
            propertiesManager.rememberLoginAfterUpdate = true
        }
    }
    
    func updater(_ updater: SUUpdater, didFinishLoading appcast: SUAppcast) {
        self.appcast = appcast
        stateUpdated?()
    }
    
}
