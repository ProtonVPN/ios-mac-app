//
//  CountryListRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion

fileprivate let HeadTitle = "Countries"
fileprivate let secureCoreSwitch = "secureCoreSwitch"
fileprivate let activateSCButton = "Activate Secure Core"
fileprivate let countrySearchButton = "countrySearchButton"
fileprivate let upgradeButton = "vpn subscription badge"
fileprivate let buttonConnectDisconnect = "ic power off"

class CountryListRobot: CoreElements {
    
    let verify = Verify()
    
    func openServerList(_ name: String) -> ServerListRobot {
        staticText(name).tap()
        return ServerListRobot()
    }
    
    func searchForServer(serverName: String) -> CountrySearchRobot {
        button(countrySearchButton).tap()
        return CountrySearchRobot().search(for: serverName)
    }
    
    func connectToFirstCountryFromList() -> ConnectionStatusRobot {
        button(buttonConnectDisconnect).byIndex(0).tap()
        return ConnectionStatusRobot()
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
    
    func getFirstServerFromList() -> String {
        return cell().firstMatch().onChild(staticText().firstMatch()).label()  ?? ""
    }
    
    @discardableResult
    func secureCoreOFf() -> CountryListRobot {
        swittch(secureCoreSwitch).tap()
        return CountryListRobot()
    }
    
    class Verify: CoreElements {
        func serverFound(server: String) -> CountryListRobot {
            cell().firstMatch().onChild(staticText(server)).waitUntilExists(time: 2).checkExists()
            return CountryListRobot()
        }
    }
}
