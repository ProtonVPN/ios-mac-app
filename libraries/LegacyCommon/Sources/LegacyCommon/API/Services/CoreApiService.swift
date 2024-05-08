//
//  CoreApiService.swift
//  vpncore - Created on 2020-10-05.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import VPNShared
import CommonNetworking

public protocol CoreApiServiceFactory {
    func makeCoreApiService() -> CoreApiService
}

public protocol CoreApiService {
    func getApiNotifications(completion: @escaping (Result<GetApiNotificationsResponse, Error>) -> Void)
    func getUserSettings() async throws -> UserSettings
}

public class CoreApiServiceImplementation: CoreApiService {
    private let networking: Networking
    
    public init(networking: Networking) {
        self.networking = networking
    }
    
    public func getApiNotifications(completion: @escaping (Result<GetApiNotificationsResponse, Error>) -> Void) {
        networking.request(CoreApiNotificationsRequest()) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(json):
                do {
                    let data = try JSONSerialization.data(withJSONObject: json as Any, options: [])
                    let decoder = JSONDecoder()
                    // this strategy is decapitalizing first letter of response's labels to get appropriate name of the ServicePlanDetails object
                    decoder.keyDecodingStrategy = .decapitaliseFirstLetter
                    decoder.dateDecodingStrategy = .secondsSince1970
                    let result = try decoder.decode(GetApiNotificationsResponse.self, from: data)

                    completion(.success(result))
                } catch let error {
                    log.error("Error parsing announcements, not retrying", category: .api, metadata: ["error": "\(error)"])
                    completion(.success(.init(notifications: [])))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    public func getUserSettings() async throws -> UserSettings {
        let response: UserSettingsResponse = try await networking.perform(request: UserSettingsRequest())
        return response.userSettings
    }
}
