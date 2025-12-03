//
//  ExtensionInfo.swift
//  macOS
//
//  Created by Jaroslav on 2021-07-30.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Dependencies
import Foundation
import PMLogger

public struct ExtensionInfo: Codable {
    let version: String
    let build: String
    let bundleId: String

    static var current: Self {
        @Dependency(\.appInfo) var appInfo
        return Self(
            version: appInfo.bundleShortVersion,
            build: appInfo.bundleVersion,
            bundleId: appInfo.identifier ?? ""
        )
    }

    public init(version: String, build: String, bundleId: String) {
        self.version = version
        self.build = build
        self.bundleId = bundleId
    }
}
