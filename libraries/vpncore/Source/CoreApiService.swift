//
//  CoreApiService.swift
//  vpncore - Created on 2020-10-05.
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

import Foundation

public protocol CoreApiServiceFactory {
    func makeCoreApiService() -> CoreApiService
}

public typealias GetApiNotificationsCallback = GenericCallback<GetApiNotificationsResponse>

public protocol CoreApiService {
    func getApiNotifications(success: @escaping GetApiNotificationsCallback, failure: @escaping ErrorCallback)
}

public class CoreApiServiceImplementation: CoreApiService {
    
    private let alamofireWrapper: AlamofireWrapper
    
    public init(alamofireWrapper: AlamofireWrapper) {
        self.alamofireWrapper = alamofireWrapper
    }
    
    public func getApiNotifications(success: @escaping GetApiNotificationsCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { json in
            do {
                let data = try JSONSerialization.data(withJSONObject: json as Any, options: [])
                let decoder = JSONDecoder()
                // this strategy is decapitalizing first letter of response's labels to get appropriate name of the ServicePlanDetails object
                decoder.keyDecodingStrategy = .custom(self.decapitalizeFirstLetter)
                decoder.dateDecodingStrategy = .secondsSince1970
                let result = try decoder.decode(GetApiNotificationsResponse.self, from: data)

                success(result)
            } catch let error {
                failure(error)
            }
        }
        alamofireWrapper.request(CoreApiNotificationsRequest(), success: successWrapper, failure: failure)
    }
    
    // MARK: - Private
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
    
    private func decapitalizeFirstLetter(_ path: [CodingKey]) -> CodingKey {
        let original: String = path.last!.stringValue
        let uncapitalized = original.prefix(1).lowercased() + original.dropFirst()
        return Key(stringValue: uncapitalized) ?? path.last!
    }
    
}
