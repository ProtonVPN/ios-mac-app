//
//  Created on 2022-12-07.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import XCTest
import ProtonCoreTestingToolkitUITestsLogin
import ProtonCoreQuarkCommands
import ProtonCoreDoh

class TokenRefreshTests: ProtonVPNUITests {

    lazy var quarkCommands = QuarkCommands(doh: doh)
    private let mainRobot = MainRobot()
    private let loginRobot = LoginRobot()

    private let user = Credentials(username: StringUtils().randomAlphanumericString(length: 10), password: "123", plan: "vpn2022")


    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
        quarkCommands.createUser(username: user.username, password: user.password, protonPlanName: user.plan)
    }

    func testLogInExpireSessionAndRefreshTokenGetUserRefreshTokenFailure() throws {

        loginRobot
            .enterCredentials(user)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToSettingsTab()

        try QuarkCommands.expireSessionSync(currentlyUsedHostUrl: doh.getCurrentlyUsedHostUrl(), username: user.username, expireRefreshToken: true)

        SettingsRobot()
            .goToAccountDetail()
            .deleteAccount()
            .verify.userIsLoggedOut()
    }

    func testLogInExpireSessionGetUserRefreshTokenSuccess() throws {
        loginRobot
            .enterCredentials(user)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()

        try QuarkCommands.expireSessionSync(currentlyUsedHostUrl: doh.getCurrentlyUsedHostUrl(), username: user.username)

        mainRobot
            .goToSettingsTab()
            .goToAccountDetail()
            .deleteAccount()
            .verify.deleteAccountScreen()
    }
}
extension QuarkCommands {
    public static func expireSessionSync(currentlyUsedHostUrl host: String,
                                         username: String,
                                         expireRefreshToken: Bool = false) throws {

        var urlString = "\(host)/internal/quark/raw::user:expire:sessions?User=\(username)"
        if expireRefreshToken {
            urlString += "&--refresh=null"
        }

        guard let url = URL(string: urlString) else { throw ExpireSessionError.cannotConstructUrl }

        let semaphore = DispatchSemaphore(value: 0)

        var result: Result<Void, ExpireSessionError>!

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                result = .failure(.callFailed(reason: error))
            } else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let unwrappedString = body, unwrappedString.contains("Expire access or refresh token") {
                        result = .success(())
                    } else {
                        result = .failure(.callFailedOfUnknownReason(responseBody: body))
                    }
                } else {
                    result = .failure(.callFailedOfUnknownReason(responseBody: body))
                }
            }
            semaphore.signal()
        }.resume()

        semaphore.wait()

        switch result {
        case .success: return
        case .failure(let error): throw error
        case .none: throw ExpireSessionError.unknownError
        }
    }

    public enum ExpireSessionError: Error {
        case cannotConstructUrl
        case callFailed(reason: Error)
        case callFailedOfUnknownReason(responseBody: String?)
        case unknownError
    }
}
