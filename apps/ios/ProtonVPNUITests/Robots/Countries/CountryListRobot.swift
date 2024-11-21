//
//  CountryListRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import Strings

fileprivate let secureCoreSwitchId = "secureCoreSwitch"
fileprivate let activateSCButton = Localizable.modalsDiscourageSecureCoreActivate
fileprivate let countrySearchButtonId = "countrySearchButton"
fileprivate let upgradeButtonId = "vpn subscription badge"
fileprivate let buttonConnectDisconnect = "ic power off"

class CountryListRobot: ConnectionBaseRobot {
    
    let verify = Verify()
    
    @discardableResult
    func openServerList(_ name: String) -> ServerListRobot {
        staticText(name).tap()
        return ServerListRobot()
    }
    
    @discardableResult
    func searchForServer(serverName: String) -> CountrySearchRobot {
        button(countrySearchButtonId).tap()
        return CountrySearchRobot().search(for: serverName)
    }
    
    @discardableResult
    func connectToCountry(_ countryName: String) -> ConnectionStatusRobot {
        staticText(countryName).firstMatch().tap()
        button(buttonConnectDisconnect).byIndex(0).tap()
        allowVpnPermission()
        return ConnectionStatusRobot()
    }
    
    @discardableResult
    func connectToAPlusCountry(_ name: String) -> HomeRobot {
        button(upgradeButtonId).byIndex(1).tap()
        allowVpnPermission()
        return HomeRobot()
    }
    
    @discardableResult
    func secureCoreOn() -> CountryListRobot {
        swittch(secureCoreSwitchId).tap()
        button(activateSCButton).tap()
        return CountryListRobot()
    }
    
    @discardableResult
    func getRandomServerFromList() -> String {
        let serverCount = app.buttons.matching(
            identifier: buttonConnectDisconnect
        ).count
        let randomIndex = Int.random(in: 0..<serverCount)
        return cell()
            .byIndex(randomIndex)
            .onChild(staticText().firstMatch())
            .label() ?? ""
    }
    
    @discardableResult
    func secureCoreOFf() -> CountryListRobot {
        swittch(secureCoreSwitchId).tap()
        return CountryListRobot()
    }
    
    class Verify: CoreElements {
        @discardableResult
        func serverFound(server: String) -> CountryListRobot {
            cell().firstMatch().onChild(staticText(server)).waitUntilExists(time: 2).checkExists()
            return CountryListRobot()
        }
    }
}
