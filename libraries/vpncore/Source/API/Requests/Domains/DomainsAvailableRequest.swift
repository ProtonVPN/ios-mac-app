//
//  DomainsAvailableRequest.swift
//  Core
//
//  Created by Marc Flores on 29.06.21.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCore_Networking

public enum DomainType: String {
    case login
    case signUp
}

final class DomainsAvailableRequest: Request {

    private let domainType: DomainType
    
    init(type: DomainType) {
        self.domainType = type
    }

    var path: String {
        return "/domains/available"
    }

    var parameters: [String: Any]? {
        return ["Type": self.domainType.rawValue]
    }

    var isAuth: Bool {
        return false
    }
}
