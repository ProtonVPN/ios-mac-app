//
//  Created on 02.05.2022.
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

public protocol SessionServiceFactory {
    func makeSessionService() -> SessionService
}

public protocol SessionService {
    func getSelector(completion: @escaping (Result<String, Error>) -> Void)
}

public final class SessionServiceImplementation: SessionService {
    private let networking: Networking

    public init(networking: Networking) {
        self.networking = networking
    }

    public func getSelector(completion: @escaping (Result<String, Error>) -> Void) {
        let request = ForkSessionRequest(clientId: "web-account-lite", independent: false)
        networking.request(request) { (result: Result<ForkSessionResponse, Error>) in
             switch result {
             case let .success(data):
                 completion(.success(data.selector))
             case let .failure(error):
                 completion(.failure(error))
             }
        }
    }
}
