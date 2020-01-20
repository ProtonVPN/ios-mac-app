//
//  ReportsApiService.swift
//  vpncore - Created on 01/07/2019.
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

import Foundation

public struct ReportBug {
    
    public let os: String // iOS, MacOS
    public let osVersion: String
    public let client: String
    public let clientVersion: String
    public let clientType: Int // 1 = email, 2 = VPN
    public var title: String
    public var description: String
    public let username: String
    public var email: String
    public var country: String
    public var ISP: String
    public var plan: String
    public var files = [URL]() // Param names: File0, File1, File2...
    
    public init(os: String, osVersion: String, client: String, clientVersion: String, clientType: Int, title: String, description: String, username: String, email: String, country: String, ISP: String, plan: String) {
        self.os = os
        self.osVersion = osVersion
        self.client = client
        self.clientVersion = clientVersion
        self.clientType = clientType
        self.title = title
        self.description = description
        self.username = username
        self.email = email
        self.country = country
        self.ISP = ISP
        self.plan = plan
    }
    
    public var canBeSent: Bool {
        return !description.isEmpty && !email.isEmpty
    }
    
}

public protocol ReportsApiServiceFactory {
    func makeReportsApiService() -> ReportsApiService
}

public class ReportsApiService {
    
    private let alamofireWrapper: AlamofireWrapper
    
    public init(alamofireWrapper: AlamofireWrapper) {
        self.alamofireWrapper = alamofireWrapper
    }
    
    public func report(bug: ReportBug,
                       success: @escaping (() -> Void),
                       failure: @escaping ((Error) -> Void)) {
        
        var i = 0
        var files = [String: URL]()
        for file in bug.files {
            files["File\(i)"] = file
            i += 1
        }
        
        let request = ReportsRouter.bug(bug)
        alamofireWrapper.upload(request,
                                parameters: request.parameters ?? [:],
                                files: files,
                                success: {_ in
                                    success()
                                },
                                failure: failure)
    }

}
