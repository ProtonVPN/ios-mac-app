//
//  MapRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion

fileprivate let HeadTitle = "Map"

class MapRobot: CoreElements {
    
    func selectCountryAndConnect() -> ConnectionStatusRobot {
        selectAndDeselect()
        return ConnectionStatusRobot()
    }
    
    func selectCountryAndDisconnect() -> MainRobot {
        button().byIndex(18).tap()
        return MainRobot()
    }
    
    @discardableResult
    private func selectAndDeselect() -> MapRobot {
        button().byIndex(18).tap()
        button().byIndex(18).tap()
        return self
    }
}
