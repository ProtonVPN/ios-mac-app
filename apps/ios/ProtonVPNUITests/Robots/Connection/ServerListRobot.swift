//
//  ServerListRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import UITestsHelpers

fileprivate let buttonConnectDisconnect = "ic power off"

class ServerListRobot: CoreElements {
    
    let verify = Verify()

    @discardableResult
    func connectToAServerViaServer() -> ConnectionStatusRobot {
        button(buttonConnectDisconnect).byIndex(0).forceTap()
        return ConnectionStatusRobot()
    }

    @discardableResult
    func disconnectFromAServerViaServer() -> MainRobot {
        button(buttonConnectDisconnect).byIndex(0).forceTap()
        return MainRobot()
    }

    @discardableResult
    func connectToAPlusServer(_ name: String) -> MainRobot {
        staticText(name).tap()
        return MainRobot()
    }
    
    class Verify: CoreElements {
        
        @discardableResult
        func serverListIsOpened(_ name: String) -> ServerListRobot {
            staticText(name).waitUntilExists().checkExists()
            return ServerListRobot()
        }
    }
}
