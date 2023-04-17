//
//  Created on 2022-01-13.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Dependencies

struct BugReportEnvironment {
    public weak var bugReportDelegate: BugReportDelegate?
    public var assetsBundle = Bundle.module
    #if os(iOS)
    public var iOSUpdateViewModel = IOSUpdateViewModel(updateIsAvailable: false)
    #endif
}

var CurrentEnv = BugReportEnvironment()

// Let's break down BugReportDelegate into pieces, so we can inject only parts of it
// into reducers. This way we can always change actual implementation of a closure
// and nothing will be changed in places where it is used.
// This time I'm not refactoring `BugReportDelegate` into something more modern
// (I could use async/await for example), just to show how we can integrate with
// `vintage` parts of the code that we do not want to update at this moment.

enum BugReportEnvironmentError: Error {
    case delegateNotSet
}

// MARK: - Send bug report

extension DependencyValues {
  var sendBugReport: @Sendable (BugReportResult) async throws -> Bool {
    get { self[SendBugReportKey.self] }
    set { self[SendBugReportKey.self] = newValue }
  }
}

private enum SendBugReportKey: DependencyKey {
    static let liveValue: @Sendable (BugReportResult) async throws -> Bool = { bugReport in
        guard let delegate = CurrentEnv.bugReportDelegate else {
            throw BugReportEnvironmentError.delegateNotSet
        }

        return try await withCheckedThrowingContinuation { continuation in
            delegate.send(form: bugReport, result: {
                switch $0 {
                case .success:
                    continuation.resume(with: .success(true))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            })
        }
    }

    static let previewValue: @Sendable (BugReportResult) async throws -> Bool = { _ in
        try await Task.sleep(nanoseconds: UInt64(1 * Double(NSEC_PER_SEC)))
        throw BugReportEnvironmentError.delegateNotSet // Return error
//        return true // Success
    }
}

// MARK: - Troubleshooting

extension DependencyValues {
  var troubleshoot: @Sendable () -> Void {
    get { self[TroubleShootingKey.self] }
    set { self[TroubleShootingKey.self] = newValue }
  }
}

private enum TroubleShootingKey: DependencyKey {
    static let liveValue: @Sendable () -> Void = {
        CurrentEnv.bugReportDelegate?.troubleshootingRequired()
    }
}

// MARK: - Finish

extension DependencyValues {
  var finishBugReport: @Sendable () -> Void {
    get { self[FinishBugReportKey.self] }
    set { self[FinishBugReportKey.self] = newValue }
  }
}

private enum FinishBugReportKey: DependencyKey {
    static let liveValue: @Sendable () -> Void = {
        CurrentEnv.bugReportDelegate?.finished()
    }
}

// MARK: - Pre-filled values

extension DependencyValues {
  var preFilledEmail: @Sendable () -> String? {
    get { self[PrefilledEmailKey.self] }
    set { self[PrefilledEmailKey.self] = newValue }
  }
}

private enum PrefilledEmailKey: DependencyKey {
    static let liveValue: @Sendable () -> String? = {
        CurrentEnv.bugReportDelegate?.prefilledEmail
    }
}

extension DependencyValues {
  var preFilledUsername: @Sendable () -> String? {
    get { self[PrefilledUsernameKey.self] }
    set { self[PrefilledUsernameKey.self] = newValue }
  }
}

private enum PrefilledUsernameKey: DependencyKey {
    static let liveValue: @Sendable () -> String? = {
        CurrentEnv.bugReportDelegate?.prefilledUsername
    }
}
