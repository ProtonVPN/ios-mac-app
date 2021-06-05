//
//  SessionsResponse.swift
//  Core
//
//  Created by Marc Flores on 19.05.21.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

public struct SessionsResponse: Codable {
    
    public let sessions: [SessionModel]
}
