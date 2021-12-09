//
//  NetworkingMock.swift
//  Core
//
//  Created by Igor Kulman on 25.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCore_Networking
import ProtonCore_Services
import ProtonCore_Authentication
@testable import vpncore

final class NetworkingMock: Networking {
    var apiService: PMAPIService {
        fatalError()
    }

    func request(_ route: LoginRequest, completion: @escaping (Result<Authenticator.Status, AuthErrors>) -> Void) {

    }

    func request(_ route: Request, completion: @escaping (Result<JSONDictionary, Error>) -> Void) {

    }

    func request(_ route: Request, completion: @escaping (Result<(), Error>) -> Void) {

    }

    func request(_ route: URLRequest, completion: @escaping (Result<String, Error>) -> Void) {

    }

    func request<T>(_ route: Request, completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable {
        
    }

    func request<T>(_ route: Request, files: [String: URL], completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable {

    }
}

extension NetworkingMock: APIServiceDelegate {
    public var locale: String {
        return NSLocale.current.languageCode ?? "en_US"
    }
    public var appVersion: String {
        return "UNIT TESTS APP VERSION"
    }
    public var userAgent: String? {
        return "UNIT TESTS USER AGENT"
    }
    public func onUpdate(serverTime: Int64) {

    }
    public func isReachable() -> Bool {
        return true
    }
    public func onDohTroubleshot() { }
}
