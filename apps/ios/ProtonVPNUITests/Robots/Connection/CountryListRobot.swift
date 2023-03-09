//
//  CountryListRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion

fileprivate let HeadTitle = "Countries"
fileprivate let buttonConnectDisconnect = "ic power off"
fileprivate let secureCoreSwitch = "secureCoreSwitch"
fileprivate let warningMessage = "Plus or Visionary subscription required"
fileprivate let okButton = "OK"
fileprivate let upgradeButton = "Upgrade"
fileprivate let activateSCButton = "Activate Secure Core"

class CountryListRobot: CoreElements {
    
    let verify = Verify()
    
    func connectToAServer() -> ConnectionStatusRobot {
        button(buttonConnectDisconnect).byIndex(1).tap()
        return ConnectionStatusRobot()
    }
    
    func disconnectViaCountry() -> MainRobot {
        button(buttonConnectDisconnect).byIndex(1).tap()
        return MainRobot()
    }
    
    func openServerList(_ name: String) -> ServerListRobot {
        staticText(name).tap()
        return ServerListRobot()
    }
    
    func connectToAPlusCountry(_ name: String) -> MainRobot {
        button(upgradeButton).byIndex(1).tap()
        return MainRobot()
    }
    
    func secureCoreOn() -> CountryListRobot {
        swittch(secureCoreSwitch).tap()
        button(activateSCButton).tap()
        return CountryListRobot()
    }
    
    @discardableResult
    func secureCoreOFf() -> CountryListRobot {
        swittch(secureCoreSwitch).tap()
        return CountryListRobot()
    }
    
    class Verify: CoreElements {
        
    }
}
