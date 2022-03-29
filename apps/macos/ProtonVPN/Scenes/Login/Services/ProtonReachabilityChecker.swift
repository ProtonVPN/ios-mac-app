//
//  Created on 29.03.2022.
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

import vpncore
import Foundation

protocol ProtonReachabilityCheckerFactory {
    func makeProtonReachabilityChecker() -> ProtonReachabilityChecker
}

protocol ProtonReachabilityChecker {
    func check(completion: @escaping (Bool) -> Void)
}

final class URLSessionProtonReachabilityChecker: ProtonReachabilityChecker {
    private var checkInProgress = false
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 3

        session = URLSession(configuration: configuration, delegate: nil, delegateQueue: .main)
    }

    func check(completion: @escaping (Bool) -> Void) {
        guard !checkInProgress else {
            return
        }

        checkInProgress = true

        let task = session.dataTask(with: URL(string: CoreAppConstants.ProtonVpnLinks.ping)!) { [weak self] _, _, error in
            self?.checkInProgress = false

            if error != nil {
                completion(false)
                return
            }

            completion(true)
        }
        task.resume()
    }
}
