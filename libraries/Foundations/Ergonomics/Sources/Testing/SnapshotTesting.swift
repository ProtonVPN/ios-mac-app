import Foundation
import IssueReporting
import SnapshotTesting
import System

public protocol AssertSnapshot {
    func snapshotDirectory() -> String?
}

/// Asserts two byte buffers are identical. On failure it reports the first differing offset with a hex
/// window around it — dumping multi-megabyte `Data` values in a failure message prints only their byte
/// counts, which for equal-length buffers reads as "identical".
public func expectSameBytes(
    _ actual: Data,
    _ expected: Data,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) {
    guard actual != expected else { return }

    func hexWindow(_ data: Data, around offset: Int) -> String {
        let window = max(data.startIndex, offset - 8) ..< min(data.endIndex, offset + 8)
        return data[window].map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    let firstDifference = zip(actual, expected).enumerated()
        .first { $1.0 != $1.1 }?.offset ?? min(actual.count, expected.count)
    reportIssue(
        """
        Byte buffers differ (\(actual.count) vs \(expected.count) bytes), first at offset \(firstDifference):
          actual:   \(hexWindow(actual, around: firstDifference))
          expected: \(hexWindow(expected, around: firstDifference))
        """,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )
}

/// Values every snapshot suite pins its environment to, defined once so no suite drifts.
public enum SnapshotEnvironment {
    /// The fixed instant to pin `\.date` to (2026-06-18T12:00:00Z, noon UTC). The globe renders real
    /// astronomy — the day/night terminator, the Moon — from the controlled date, so pinning to
    /// `Date()` (the wall clock) would bake each run's calendar date into the reference images and
    /// they would silently rot as time passes.
    public static let date = Date(timeIntervalSince1970: 1_781_784_000)
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

    /// Precision pair for GPU-rendered snapshots: a near-exact pixel match, with a perceptual tolerance
    /// absorbing the sub-pixel MSAA-edge differences that vary across GPU hardware between the recording
    /// machine and CI. Shared so every GPU suite fails at the same threshold.
    static var gpuSnapshotPrecision: Float {
        0.99
    }

    static var gpuPerceptualPrecision: Float {
        0.98
    }

    /// The standard CI snapshot directory for a suite: `<CI_PROJECT_DIR>/<testsDirectory>/__Snapshots__/
    /// <suite-file-stem>`, or `nil` locally, which falls back to SnapshotTesting's default layout next to
    /// the test file. `testsDirectory` stays explicit because the repo-relative path can't be derived from
    /// `#filePath` reliably across build and run machines, but the shape lives here once.
    static func ciSnapshotDirectory(testsDirectory: String, file: String = #filePath) -> String? {
        guard let projectDir else { return nil }
        let suite = FilePath(file).lastComponent?.stem ?? ""
        return "\(projectDir)/\(testsDirectory)/__Snapshots__/\(suite)"
    }

    func assertSnapshot<Value>(
        of value: @autoclosure () throws -> Value,
        as snapshotting: Snapshotting<Value, some Any>,
        named name: String? = nil,
        record recording: SnapshotTestingConfiguration.Record? = nil,
        timeout: TimeInterval = 5,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let failure: String?
        do {
            failure = try withSnapshotTesting(record: recording, diffTool: .ci_or_preview) {
                try verifySnapshot(
                    of: value(),
                    as: snapshotting,
                    named: name,
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
