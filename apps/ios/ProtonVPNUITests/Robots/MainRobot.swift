//
//  MainRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest


fileprivate let tabProfiles = "Profiles"
fileprivate let tabSettings = "Settings"

// MainRobot class contains actions for main app view.

class MainRobot: CoreElements {
    
    func goToProfilesTab() -> ProfileRobot {
        button(tabProfiles).tap()
        return ProfileRobot()
    }

    func goToSettingsTab() -> SettingsRobot {
        button(tabSettings).tap()
        return SettingsRobot()
    }
}
