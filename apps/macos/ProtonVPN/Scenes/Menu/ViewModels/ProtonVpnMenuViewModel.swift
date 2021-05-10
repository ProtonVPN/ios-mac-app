//
//  ProtonVpnMenuViewModel.swift
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

protocol ProtonVpnMenuViewModelFactory {
    func makeProtonVpnMenuViewModel() -> ProtonVpnMenuViewModel
}

extension DependencyContainer: ProtonVpnMenuViewModelFactory {
    func makeProtonVpnMenuViewModel() -> ProtonVpnMenuViewModel {
        return ProtonVpnMenuViewModel(factory: self)
    }
}

class ProtonVpnMenuViewModel {
    
    typealias Factory = AppSessionManagerFactory & NavigationServiceFactory & UpdateManagerFactory
    public let factory: Factory
    
    private let appSessionManager: AppSessionManager
    private let navService: NavigationService
    
    var contentChanged: (() -> Void)?
    
    init(factory: Factory) {
        self.factory = factory
        self.appSessionManager = factory.makeAppSessionManager()
        self.navService = factory.makeNavigationService()
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged(_:)),
                                               name: appSessionManager.sessionChanged, object: nil)
    }
    
    var isPreferencesEnabled: Bool {
        return appSessionManager.sessionStatus == .established
    }
    
    var isLogOutEnabled: Bool {
        return appSessionManager.sessionStatus == .established
    }
    
    func openAboutAction() {
        navService.openAbout(factory: factory)
    }
    
    func checkForUpdatesAction() {
        navService.checkForUpdates()
    }
    
    func openPreferencesAction() {
        navService.openSettings(to: .general)
    }
    
    func logOutAction() {
        navService.logOutRequested()
    }
    
    func showAllAction() {
        navService.showApplication()
    }
    
    func quitAction() {
        NSApp.terminate(self)
    }
    
    // MARK: - Private functions
    @objc private func sessionChanged(_ notification: Notification) {
        contentChanged?()
    }
}
