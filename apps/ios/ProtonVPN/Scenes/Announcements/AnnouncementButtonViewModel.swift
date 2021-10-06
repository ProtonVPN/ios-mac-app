//
//  AnnouncementButtonViewModel.swift
//  ProtonVPN - Created on 2020-10-21.
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

import vpncore

protocol AnnouncementButtonViewModelFactory {
    func makeAnnouncementButtonViewModel() -> AnnouncementButtonViewModel
}

extension DependencyContainer: AnnouncementButtonViewModelFactory {
    func makeAnnouncementButtonViewModel() -> AnnouncementButtonViewModel {
        return AnnouncementButtonViewModel(factory: self)
    }
}

class AnnouncementButtonViewModel {
    
    // Must be pre-set in AppDelegate!
    public static var shared: AnnouncementButtonViewModel!
    
    public typealias Factory = PropertiesManagerFactory & AnnouncementManagerFactory & AnnouncementsViewModelFactory
    private let factory: Factory

    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var announcementManager: AnnouncementManager = factory.makeAnnouncementManager()
    private lazy var announcementsViewModel: AnnouncementsViewModel = factory.makeAnnouncementsViewModel()
    
    public init(factory: Factory) {
        self.factory = factory
    }
    
    // MARK: Main part
    
    public var showAnnouncements: Bool {
        guard propertiesManager.featureFlags.pollNotificationAPI else {
            return false
        }
        return !announcementManager.fetchCurrentAnnouncements().isEmpty
    }
    
    public var hasUnreadAnnouncements: Bool {
        return announcementManager.hasUnreadAnnouncements
    }

    public func showAnnouncement() {
        announcementsViewModel.open()
    }
}
