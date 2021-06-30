//
//  DomainsAvailableRequest.swift
//  Core
//
//  Created by Marc Flores on 29.06.21.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

public enum DomainType: String {
    case login
    case signUp
}

final class DomainsAvailableRequest: BaseRequest {

    private let domainType: DomainType
    
    init(type: DomainType) {
        self.domainType = type
        super.init()
    }
    
    override var parameters: [String: Any]? {
        return ["Type": self.domainType.rawValue]
    }
    
    override func path() -> String {
        return super.path() + "/domains/available"
    }
}
