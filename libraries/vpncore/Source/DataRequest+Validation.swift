//
//  DataRequest+Validation.swift
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

extension DataRequest {
    
    //Custom validation for our future requests
    
    var validated: DataRequest {
        let validation: Validation = { request, response, data in
            let statusCode = response.statusCode
            if let json = data?.jsonDictionary, let code = json.int(key: "Code") {
                if statusCode == 200 && code == 1000 {
                    return .success(Void())
                } else {
                    return .failure(ApiError(httpStatusCode: statusCode, code: code, localizedDescription: json.string("Error"), responseBody: json))
                }
            } else {
                return .failure(ApiError.unknownError)
            }
        }
        return validate( validation )
    }
}
