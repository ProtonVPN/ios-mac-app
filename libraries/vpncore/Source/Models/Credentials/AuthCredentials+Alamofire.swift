//
//  AuthCredentials+Alamofire.swift
//  Core
//
//  Created by Jaroslav on 2021-06-22.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import Alamofire

// Used for refreshing auth token on API
extension AuthCredentials: AuthenticationCredential {
    
    // Refresh the token even before we actually receive 401 from the server.
    public var requiresRefresh: Bool {
        return Date(timeIntervalSinceNow: 60 * 5) > expiration
    }
    
}
