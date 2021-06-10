//
//  MockLogFilesProvider.swift
//  ProtonVPNTests
//
//  Created by Jaroslav on 2021-06-04.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
@testable import vpncore

class MockLogFilesProvider: LogsFilesProvider {
    public var logFiles = [(String, URL?)]()
}
