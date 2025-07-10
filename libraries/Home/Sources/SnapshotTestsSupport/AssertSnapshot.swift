//
//  Created on 2025-06-24 by Pawel Jurczyk.
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

import IssueReporting
import SnapshotTesting

import Foundation

public protocol AssertSnapshot {
    func snapshotDirectory() -> String?
}

public extension AssertSnapshot {
    func assertSnapshot<Value>(
        of value: @autoclosure () throws -> Value,
        as snapshotting: Snapshotting<Value, some Any>,
        named name: String? = nil,
        record recording: Bool? = nil,
        timeout: TimeInterval = 5,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        var failure: String?
        do {
            failure = try withSnapshotTesting(diffTool: .magick) {
                try verifySnapshot(
                    of: value(),
                    as: snapshotting,
                    named: name,
                    record: recording,
                    snapshotDirectory: snapshotDirectory(),
                    timeout: timeout,
                    fileID: fileID,
                    file: filePath,
                    testName: testName,
                    line: line,
                    column: column
                )
            }
        } catch {
            failure = error.localizedDescription
        }
        guard let failure else { return }
        reportIssue(failure, fileID: fileID, filePath: filePath, line: line, column: column)
    }
}
