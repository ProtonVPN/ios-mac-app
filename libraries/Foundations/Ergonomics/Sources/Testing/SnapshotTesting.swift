import IssueReporting
import SnapshotTesting
import System

import Foundation

public protocol AssertSnapshot {
    func snapshotDirectory() -> String?
}

public extension AssertSnapshot {
    static var projectDir: String? {
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
            projectDir
        } else {
            nil
        }
    }

    static var outputDir: FilePath? {
        guard let projectDir else { return nil }

        return FilePath(projectDir)
            .appending("output")
            .appending("Snapshots")
    }

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
        let failure: String?
        do {
            failure = try withSnapshotTesting(diffTool: .ci_or_preview) {
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

        reportIssue(
            failure,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }
}

private extension SnapshotTestingConfiguration.DiffTool {
    static let ci_or_preview = Self {
        let env = ProcessInfo.processInfo.environment

        // If we're not running in CI, just emit the usual command.
        guard let projectDir = env["CI_PROJECT_DIR"], !projectDir.isEmpty else {
            return "magick compare \"\($0)\" \"\($1)\" png: | open -f -a Preview.app"
        }

        let actual = FilePath($1)
        let outputDir = FilePath(projectDir)
            .appending("output")
            .appending("Snapshots")

        // Either take the subpath starting from `SnapshotTests`, or the very last element.
        let index = actual.components
            .firstIndex(where: {
                $0.string.hasSuffix("SnapshotTests") ||
                    $0.string.hasSuffix("Snapshots")
            }) ?? actual.components.endIndex

        // Then, append that subpath to the output dir.
        let destination = actual.components[index...].reduce(outputDir) { $0.appending($1) }

        // This gets scanned by a command after the tests have been run to place differing snapshots into artifacts.
        return """
        SnapshotFailed: {"Original": "\($0)", "Actual": "\($1)", "Destination": "\(destination.string)"}
        """
    }
}
