//
//  AFDataResponse+Debugging.swift
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

extension DataResponse {
    
    /// Prints debug info. Only for local debugging,
    func debugLog() {
        #if DEBUG
//        debugPrint("======================================= start =======================================")
//        debugPrint(request?.url as Any)
//        debugPrint(request?.allHTTPHeaderFields as Any)
//        if let data = request?.httpBody {
//            debugPrint(String(data: data, encoding: .utf8) as Any)
//        }
//        debugPrint("------------------------------------- response -------------------------------------")
//        debugPrint(response?.statusCode as Any)
//        if let result = try? result.get() {
//            debugPrint(result as Any)
//        }
//        debugPrint("======================================= end =======================================")
        #endif
    }
}
