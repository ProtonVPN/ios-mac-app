//
//  ReportsApiService.swift
//  vpncore - Created on 01/07/2019.
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

import Foundation
import ProtonCoreAPIClient
import BugReport
import CommonNetworking
import VPNShared

public typealias DynamicBugReportConfigCallback = GenericCallback<BugReportModel>

public protocol ReportsApiServiceFactory {
    func makeReportsApiService() -> ReportsApiService    
}

public class ReportsApiService {
    private let networking: Networking
    private let authKeychain: AuthKeychainHandle

    public typealias Factory = NetworkingFactory &
        AuthKeychainHandleFactory

    public convenience init(_ factory: Factory) {
        self.init(networking: factory.makeNetworking(),
                  authKeychain: factory.makeAuthKeychainHandle())
    }
    
    public init(networking: Networking, authKeychain: AuthKeychainHandle) {
        self.networking = networking
        self.authKeychain = authKeychain
    }
    
    public func report(bug: ReportBug, completion: @escaping (Result<(), Error>) -> Void) {
        let files = bug.files.reachable()
            .enumerated()
            .reduce(into: [String: URL]()) { result, file in
                result["File\(file.offset)"] = file.element
            }

        let request = ReportsBugs(bug, authKeychain: authKeychain)
        networking.request(request, files: files) { (result: Result<ReportsBugResponse, Error>) in
            switch result {
            case .success:
                completion(.success)
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    public func dynamicBugReportConfig(completion: @escaping (Result<BugReportModel, Error>) -> Void) {
        networking.request(DynamicBugReportConfigRequest(), completion: completion)
    }
}
