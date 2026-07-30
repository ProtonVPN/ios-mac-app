//
//  Created on 07.05.2026 by John Biggs.
//
//  Copyright (c) 2026 Proton AG
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

import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

#if canImport(StoreKit)
    import StoreKit
#endif

import ComposableArchitecture
import Connection
import Domain
import Sharing

@Reducer
public struct ReviewFeature {
    @ObservableState
    public struct State: Equatable {
        static let formatter: DateComponentsFormatter = {
            let format = DateComponentsFormatter()
            format.unitsStyle = .abbreviated
            format.allowedUnits = [.day, .hour, .minute, .second]
            return format
        }()

        @SharedReader(.userPlan) var userPlan
        @SharedReader(.ratingSettings) var ratingSettings
        @SharedReader(.whenLastReviewShown) var reviewTimestamp
        @SharedReader(.whenFirstSuccessfulConnectionStarted) var successfulTimestamp
        @SharedReader(.whenActiveConnectionStarted) var activeConnectionStartTimestamp
        @SharedReader(.successfulConnectionsInARow) var successfulConnectionsInARow

        var shouldPrompt: Bool {
            @Dependency(\.date) var date

            guard let userPlan else {
                // App isn't ready yet, don't log, just return early
                return false
            }

            // If the user's plan is in the list of eligible plans, and...
            guard ratingSettings.eligiblePlans.contains(userPlan) else {
                log.info("No prompt: plan \(userPlan) not eligible (need one of \(ratingSettings.eligiblePlans))")
                return false
            }

            // the user has successfully connected, and...
            guard let successfulTimestamp else {
                log.info("User has not successfully connected yet; not prompting")
                return false
            }

            // sufficient time has passed since the first connection, and...
            let minDays = ratingSettings.daysFromFirstConnection
            let connectionReviewDate = successfulTimestamp.addingTimeInterval(.days(minDays))
            guard connectionReviewDate < date.now else {
                let until = Self.formatter.string(from: date.now, to: connectionReviewDate) ?? "??"
                log.info("Not showing review prompt for at least another \(until) (setting > \(minDays)d)")
                return false
            }

            // the user has not recently given a rating, and...
            let minReviewDays = ratingSettings.daysLastReviewPassed
            let nextReviewDate = reviewTimestamp?.addingTimeInterval(.days(minReviewDays)) ?? .distantPast
            guard nextReviewDate < date.now else {
                let until = Self.formatter.string(from: date.now, to: nextReviewDate) ?? "??"
                let when = reviewTimestamp?.formatted(date: .abbreviated, time: .shortened) ?? "??"
                log.info("Shown on \(when), not showing for another \(until) (setting >\(minReviewDays)d)")
                return false
            }

            // the user has either had N successful connections, or...
            if successfulConnectionsInARow >= ratingSettings.successConnections {
                log.info("Prompting: \(successfulConnectionsInARow) connections >= \(ratingSettings.successConnections)")
                return true
            }

            // the user has maintained an active connection for M days, then show the prompt.
            let minActiveDays = ratingSettings.daysConnected
            let minActiveDate = activeConnectionStartTimestamp?.addingTimeInterval(.days(minActiveDays)) ?? .distantFuture
            if minActiveDate < date.now {
                let since = Self.formatter.string(from: activeConnectionStartTimestamp!, to: date.now) ?? "??"
                log.info("Prompting: user has been connected for \(since) (setting > \(minActiveDays)d)")
                return true
            }

            // Otherwise, do not prompt.
            let startDescription = activeConnectionStartTimestamp.map {
                "since \($0.formatted(date: .abbreviated, time: .shortened))"
            } ?? "does not exist"

            log.info(
                """
                No prompt - only \(successfulConnectionsInARow) connections. Active connection \(startDescription) while \
                config requires \(minActiveDays) days connected and >= \(ratingSettings.successConnections) connections
                """
            )
            return false
        }
    }

    public enum Action {
        /// Just come up; listen to account change and app activation events.
        case listen

        /// The app has come into foreground or otherwise wants to manually check review conditions.
        case activate

        /// The app has successfully connected.
        case connected

        /// The app has disconnected due to an error.
        case connectionFailed
    }

    private enum CancelIDs {
        case watchDidBecomeActive
        case watchSuccessfulConnectionsInARow
    }

    private let longLivingSuccessfulConnectionsCounter: Effect<Action> = .publisher {
        @SharedReader(.successfulConnectionsInARow) var successfulConnectionsInARow
        let publisher = $successfulConnectionsInARow.publisher
        return publisher
            .zip(publisher.dropFirst())
            .filter { old, new in new > old }
            .map { _ in Action.connected }
    }.cancellable(id: CancelIDs.watchSuccessfulConnectionsInARow)

    private let longLivingDidBecomeActiveEffect: Effect<Action> = .publisher {
        NotificationCenter.default
            .publisher(for: didBecomeActiveNotification)
            .map { _ in Action.activate }
    }.cancellable(id: CancelIDs.watchDidBecomeActive)

    @Dependency(\.date) var date

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .listen:
                return .merge(
                    longLivingDidBecomeActiveEffect,
                    longLivingSuccessfulConnectionsCounter
                )
            case .activate:
                if state.shouldPrompt {
                    @Dependency(\.reviewPrompter) var reviewPrompter
                    reviewPrompter.prompt()
                }
                return .none
            case .connected:
                return .send(.activate)
            case .connectionFailed:
                @Dependency(\.ratingBooster) var ratingBooster
                ratingBooster.connectionFailed()
                return .none
            }
        }
    }
}

public extension SharedKey where Self == AppStorageKey<RatingSettings>.Default {
    static var ratingSettings: Self {
        Self[.appStorage("RatingSettings"), default: RatingSettings()]
    }
}

public extension SharedKey where Self == AppStorageKey<Int>.Default {
    static var successfulConnectionsInARow: Self {
        Self[.appStorage("successfulConnectionsInARow"), default: 0]
    }
}

public extension SharedKey where Self == AppStorageKey<Date?>.Default {
    static var whenLastReviewShown: Self {
        Self[.appStorage("whenLastReviewShown"), default: nil]
    }

    static var whenActiveConnectionStarted: Self {
        Self[.appStorage("whenActiveConnectionStarted"), default: nil]
    }

    static var whenFirstSuccessfulConnectionStarted: Self {
        Self[.appStorage("whenFirstSuccessfulConnectionStarted"), default: nil]
    }
}

struct ReviewPrompter: DependencyKey {
    let prompt: () -> Void

    static var liveValue = ReviewPrompter {
        @Shared(.whenLastReviewShown) var reviewTimestamp
        @Dependency(\.date) var date
        #if canImport(UIKit) && canImport(StoreKit)
            let activeScene = UIApplication.shared
                .connectedScenes
                .first { $0.activationState == .foregroundActive } as? UIWindowScene

            if let activeScene {
                SKStoreReviewController.requestReview(in: activeScene)
            }
        #elseif canImport(StoreKit)
            SKStoreReviewController.requestReview()
        #endif
        $reviewTimestamp.withLock {
            $0 = date.now
        }
    }

    #if DEBUG
        /// Sets a simple ``SharedKey`` to say that the prompt did in fact happen.
        static var testValue = ReviewPrompter {
            @Shared(.didPromptReview) var didPrompt
            $didPrompt.withLock {
                $0 = true
            }
            @Dependency(\.date) var date
            @Shared(.whenLastReviewShown) var reviewTimestamp
            $reviewTimestamp.withLock {
                $0 = date.now
            }
        }
    #endif
}

extension DependencyValues {
    var reviewPrompter: ReviewPrompter {
        get { self[ReviewPrompter.self] }
        set { self[ReviewPrompter.self] = newValue }
    }
}

#if DEBUG // for testing
    package extension SharedKey where Self == InMemoryKey<Bool>.Default {
        static var didPromptReview: Self {
            Self[.inMemory("didPromptReview"), default: false]
        }
    }
#endif

import Combine

public struct RatingBooster: TestDependencyKey {
    public static let testValue = RatingBooster()

    private var cancellables: Set<AnyCancellable> = .init()

    @SharedReader(.userPlan) var userPlan
    @Shared(.whenLastReviewShown) var reviewTimestamp
    @Shared(.whenFirstSuccessfulConnectionStarted) var successfulTimestamp
    @Shared(.whenActiveConnectionStarted) var activeConnectionStartTimestamp
    @Shared(.successfulConnectionsInARow) var successfulConnectionsInARow

    @Dependency(\.date) var date

    init() {
        @SharedReader(.userPlan) var userPlan
        let publisher = $userPlan.publisher
        publisher
            .zip(publisher.dropFirst())
            .filter { $0 != $1 }
            .sink { [self] _ in clear() }
            .store(in: &cancellables)

        @SharedReader(.connectionState) var connectionState
        let connectionPublisher = $connectionState.publisher
        connectionPublisher
            .zip(connectionPublisher.dropFirst())
            .filter { oldValue, newValue in
                if newValue.is(\.connected), !oldValue.is(\.connected) {
                    return true
                } else if newValue.is(\.disconnected), !oldValue.is(\.disconnected) {
                    return true
                }
                return false
            }
            .sink(receiveValue: connectionStateUpdate)
            .store(in: &cancellables)
    }

    /// Clear the review settings from defaults.
    func clear() {
        $successfulConnectionsInARow.withLock { $0 = 0 }
        $activeConnectionStartTimestamp.withLock { $0 = nil }
        $successfulTimestamp.withLock { $0 = nil }
        $reviewTimestamp.withLock { $0 = nil }
    }

    func connectionFailed() {
        $activeConnectionStartTimestamp.withLock { $0 = nil }
        $successfulConnectionsInARow.withLock { $0 = 0 }
    }

    func connectionStateUpdate(oldValue: ConnectionState, newValue: ConnectionState) {
        if newValue.is(\.connected), !oldValue.is(\.connected) {
            if successfulTimestamp == nil {
                log.info("Saving first successful connection timestamp.")
                $successfulTimestamp.withLock { $0 = date.now }
            }

            if activeConnectionStartTimestamp == nil {
                $activeConnectionStartTimestamp.withLock { $0 = date.now }
                $successfulConnectionsInARow.withLock { $0 += 1 }
            }
        } else if newValue.is(\.disconnected), !oldValue.is(\.disconnected) {
            $activeConnectionStartTimestamp.withLock { $0 = nil }
        }
    }

    public static var liveValue: RatingBooster = .init()
}

public extension DependencyValues {
    var ratingBooster: RatingBooster {
        get { self[RatingBooster.self] }
        set { self[RatingBooster.self] = newValue }
    }
}
