//
//  Created on 2022-04-21.
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

struct MockConnectionSessionFactory: ConnectionSessionFactory {
    typealias RequestCallback = (ConnectionSession, URLRequest, MockConnectionSession.CompletionCallback) -> Void
    let requestCallback: RequestCallback

    func connect(hostname: String, port: String, useTLS: Bool) -> ConnectionSession {
        return MockConnectionSession(hostname: hostname, port: port, useTLS: useTLS, callback: requestCallback)
    }
}

struct MockConnectionSession: ConnectionSession {
    typealias CompletionCallback = ((Data?, HTTPURLResponse?, Error?) -> Void)

    let hostname: String
    let port: String
    let useTLS: Bool

    let callback: MockConnectionSessionFactory.RequestCallback

    func request(_ request: URLRequest, completionHandler: @escaping CompletionCallback) {
        callback(self, request, completionHandler)
    }
}
