//
//  AFDataResponse+Filter.swift
//  vpncore - Created on 08/05/2020.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Alamofire

public enum ApiResponse {
    case success(JSONDictionary)
    case failure(Error)
}

extension DataResponse {
    var mapApiResponse: ApiResponse {
        if let error = self.error as? ApiError {
            return .failure(error)
        } else if let json = self.data?.jsonDictionary, let statusCode = self.response?.statusCode, let code = json.int(key: "Code") {
            if statusCode == 200 && code == 1000 {
                return .success(json)
            } else {
                return .failure(ApiError(httpStatusCode: statusCode, code: code, localizedDescription: json.string("Error"), responseBody: json))
            }
        } else {
            print("--------------------MAP--ERROR---------------------------------------")
            print("\(self.error)")
            return .failure(self.error ?? ApiError.unknownError)
        }
    }
}
