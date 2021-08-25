//
//  NetworkingMock.swift
//  Core
//
//  Created by Igor Kulman on 25.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCore_Networking

final class NetworkingMock: Networking {
    func request(_ route: Request, completion: @escaping (Result<JSONDictionary, Error>) -> Void) {

    }

    func request(_ route: Request, completion: @escaping (Result<(), Error>) -> Void) {

    }

    func request(_ route: URLRequest, completion: @escaping (Result<String, Error>) -> Void) {

    }
}
