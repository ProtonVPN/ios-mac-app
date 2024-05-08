//
//  CoreApiServiceMock.swift
//  vpncore - Created on 2020-10-19.
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

#if DEBUG
import Foundation
import CommonNetworking

public enum CoreAPIServiceMockError: Error {
    case mockNotProvided
}

public class CoreApiServiceMock: CoreApiService {
    public var callbackGetApiNotificationsCallback: ((@escaping GenericCallback<GetApiNotificationsResponse>, @escaping ErrorCallback) -> Void)?

    public func getApiNotifications(completion: @escaping (Result<GetApiNotificationsResponse, Error>) -> Void) {
        callbackGetApiNotificationsCallback?({ response in
            completion(.success(response))
        }, { error in
            completion(.failure(error))
        })
    }

    public var getUserSettingsReturnValue: UserSettings?

    public func getUserSettings() async throws -> UserSettings {
        if let getUserSettingsReturnValue {
            return getUserSettingsReturnValue
        } else {
            throw CoreAPIServiceMockError.mockNotProvided
        }
    }

    public init() {}
}

#endif
