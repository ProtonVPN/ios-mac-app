//
//  Created on 27.03.2025 by John Biggs.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import XCTest
import System
import SnapshotTesting
import IssueReporting
import SwiftUI

class TVSnapshotTestCase: XCTestCase {
    static let precision: Float = 0.99
    static let perceptualPrecision: Float = 0.98

    func snap(
        _ view: @autoclosure () throws -> some View,
        caseName: String,
        trait: UIUserInterfaceStyle,
        record recording: Bool? = nil,
        timeout: TimeInterval = 5,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        var snapshotDirectory: String?
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"] {
            let path = FilePath(String(describing: filePath))

            let suite = path.lastComponent?.stem ?? ""
            snapshotDirectory = "\(projectDir)/libraries/tvOS/Tests/tvOSSnapshotTests/__Snapshots__/\(suite)"
        }

        let failure = try verifySnapshot(
            of: view(),
            as: .image(
                precision: Self.precision,
                perceptualPrecision: Self.perceptualPrecision,
                traits: trait.collection
            ),
            record: recording,
            snapshotDirectory: snapshotDirectory,
            timeout: timeout,
            fileID: fileID,
            file: filePath,
            testName: "\(caseName) \(trait.name)",
            line: line,
            column: column
        )
        guard let message = failure else { return }
        reportIssue(message, fileID: fileID, filePath: filePath, line: line, column: column)
    }
}
