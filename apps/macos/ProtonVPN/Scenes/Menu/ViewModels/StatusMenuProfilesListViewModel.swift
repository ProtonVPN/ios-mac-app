//
//  StatusMenuProfilesListViewModel.swift
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

import Dependencies
import Domain
import Foundation
import LegacyCommon
import VPNAppCore

class StatusMenuProfilesListViewModel {
    @Dependency(\.credentialsProvider) private var credentialsProvider
    @Dependency(\.profileManager) private var profileManager

    var contentChanged: (() -> Void)?

    var cellHeight: CGFloat {
        44
    }

    var cellCount: Int {
        profileManager.allProfiles().count
    }

    private var userTier: Int {
        credentialsProvider.tier
    }

    init() {
        AppEvent.profileContentChanged.subscribe(self, selector: #selector(profilesChanged))
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func cellModel(forIndex index: Int) -> StatusMenuProfileItemViewModel? {
        let allProfiles = profileManager.allProfiles()
        guard allProfiles.indices.contains(index) else { return nil }
        let profile = allProfiles[index]
        return StatusMenuProfileItemViewModel(profile: profile, userTier: userTier)
    }

    @objc
    private func profilesChanged() {
        contentChanged?()
    }
}
