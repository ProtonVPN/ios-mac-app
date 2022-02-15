//
//  CountryListRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest

fileprivate let HeadTitle = "Countries"
fileprivate let buttonConnectDisconnect = "con available"
fileprivate let secureCore = "Use Secure Core"
fileprivate let warningMessage = "Plus or Visionary subscription required"
fileprivate let okButton = "OK"

class CountryListRobot: CoreElements {
    
    let verify = Verify()
    
    func connectToAserver() -> ConnectionStatusRobot {
        button(buttonConnectDisconnect).byIndex(1).tap()
        return ConnectionStatusRobot()
    }
    
    func diconnectViaCountry() -> MainRobot {
        button(buttonConnectDisconnect).byIndex(1).tap()
        return MainRobot()
    }
    
    func openServerList(_ name: String) -> ServerListRobot {
        staticText(name).tap()
        return ServerListRobot()
    }
    
    func connectToAPlusCountry(_ name: String) -> MainRobot {
        staticText(name).tap()
        return MainRobot()
    }
    
    func secureCoreOn() -> CountryListRobot {
        swittch(secureCore).tap()
        return CountryListRobot()
    }
    
    class Verify: CoreElements {
        
        func countryTabIsOpen() -> CountryListRobot {
            staticText(HeadTitle).wait().checkExists()
            return CountryListRobot()
        }
    }
}
