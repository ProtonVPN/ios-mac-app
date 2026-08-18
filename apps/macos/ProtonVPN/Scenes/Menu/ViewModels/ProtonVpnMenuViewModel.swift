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
import Combine
import Dependencies
import Domain
import Ergonomics
import Sharing

protocol ProtonVpnMenuViewModelFactory {
    func makeProtonVpnMenuViewModel() -> ProtonVpnMenuViewModel
}

extension DependencyContainer: ProtonVpnMenuViewModelFactory {
    func makeProtonVpnMenuViewModel() -> ProtonVpnMenuViewModel {
        ProtonVpnMenuViewModel(factory: self)
    }
}

class ProtonVpnMenuViewModel {
    typealias Factory = NavigationServiceFactory
    let factory: Factory

    private let navService: NavigationService

    @SharedReader(.sessionStatus) private var sessionStatus: SessionStatus

    var contentChanged: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()

    init(factory: Factory) {
        self.factory = factory
        self.navService = factory.makeNavigationService()
        $sessionStatus.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.contentChanged?() }
            .store(in: &cancellables)
    }

    var isPreferencesEnabled: Bool {
        sessionStatus == .established
    }

    var isLogOutEnabled: Bool {
        sessionStatus == .established
    }

    func openAboutAction() {
        navService.openAbout(factory: factory)
    }

    func checkForUpdatesAction() {
        @Dependency(\.updateManager) var updateManager
        updateManager.checkForUpdates(userInitiated: true)
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
}
