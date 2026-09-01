#if canImport(AppKit)
    import AppKit
#endif
import Foundation
import IssueReporting
import SnapshotTesting
import System

public protocol AssertSnapshot {
    func snapshotDirectory() -> String?
}

/// Asserts two byte buffers are identical. On failure it reports the first differing offset with a hex window around it
/// — dumping multi-megabyte `Data` values in a failure message prints only their byte counts, which for equal-length
/// buffers reads as "identical".
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
        let center = data.startIndex + offset
        let window = max(data.startIndex, center - 8) ..< min(data.endIndex, center + 8)
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
    /// The fixed instant to pin `\.date` to (2026-06-18T12:00:00Z, noon UTC). The globe renders real astronomy — the
    /// day/night terminator, the Moon — from the controlled date, so pinning to `Date()` (the wall clock) would bake
    /// each run's calendar date into the reference images and they would silently rot as time passes.
    public static let date = Date(timeIntervalSince1970: 1_781_784_000)
}

#if canImport(AppKit)
    public extension SnapshotEnvironment {
        /// One of the two appearances a macOS snapshot renders in.
        ///
        /// A suite that records the same screen light and dark takes this as a test argument, which
        /// `NSAppearance.Name` cannot be: it wraps a string and lists no cases. The raw value also names the
        /// reference image, so both suites that do it name their files the same way.
        enum Appearance: String, CaseIterable, Sendable {
            case light
            case dark

            /// The AppKit appearance the application is set to while the snapshot renders.
            var name: NSAppearance.Name {
                switch self {
                case .light: .aqua
                case .dark: .darkAqua
                }
            }
        }

        /// Renders `body` against `appearance`, then puts back whatever was set before.
        ///
        /// macOS snapshots have to pin this. Theme resolves its colors through `NSAppearance`, and `NSApp`
        /// follows the system theme unless told otherwise, so a Mac set to switch automatically renders one way
        /// by day and the other by night. A reference recorded in the morning then fails in the evening.
        ///
        /// Note that `\.colorScheme` does not stand in for it: that reaches SwiftUI's own colors, not Theme's.
        @MainActor
        static func withAppearance<T>(
            _ appearance: Appearance = .dark,
            _ body: () throws -> T
        ) rethrows -> T {
            _ = NSApplication.shared
            let previous = NSApp.appearance
            defer { NSApp.appearance = previous }
            NSApp.appearance = NSAppearance(named: appearance.name)
            return try body()
        }
    }
#endif

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
        let root = FilePath(projectDir)
        let outputDir = root
            .appending("output")
            .appending("Snapshots")

        // `ciSnapshotDirectory(testsDirectory:)` builds every suite's snapshot directory under
        // `CI_PROJECT_DIR`, so the destination mirrors the repo-relative path of the failing snapshot:
        // `output/Snapshots/libraries/.../Tests/<PackageTests>/__Snapshots__/<Suite>/<test>.png`. Mirroring the
        // repo layout keeps destinations unique by construction — matching path components against a naming
        // convention broke for any suite whose tests directory wasn't named `*SnapshotTests`, and every such
        // suite collapsed onto the bare output directory.
        //
        // A suite whose `snapshotDirectory()` points outside the repo (none do today) keeps only its file
        // name: lossy, but never an empty subpath.
        let relative = actual.starts(with: root)
            ? actual.components.dropFirst(root.components.count)
            : actual.components.suffix(1)
        let destination = relative.reduce(outputDir) { $0.appending($1) }

        // This gets scanned by a command after the tests have been run to place differing snapshots into artifacts.
        return """
        SnapshotFailed: {"Original": "\($0)", "Actual": "\($1)", "Destination": "\(destination.string)"}
        """
    }
}
