//
//  ExtensionInfo.swift
//  macOS
//
//  Created by Jaroslav on 2021-07-30.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

struct ExtensionInfo: Codable {
    let version: String
    let build: String
    let bundleId: String
    
    static var current: Self {
        return Self(version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
                    build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0",
                    bundleId: Bundle.main.bundleIdentifier ?? "")
    }
        
}
