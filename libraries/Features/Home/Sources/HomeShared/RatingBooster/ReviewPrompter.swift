//
//  Created on 2026-07-31 by Pawel Jurczyk.
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

import Dependencies
import Domain
import Sharing
import Telemetry

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

#if canImport(StoreKit)
    import StoreKit
#endif

struct ReviewPrompter: DependencyKey {
    let prompt: () async -> Void

    static let liveValue = ReviewPrompter {
        let requested = await MainActor.run { () -> Bool in
            #if canImport(UIKit) && canImport(StoreKit)
                let activeScene = UIApplication.shared
                    .connectedScenes
                    .first { $0.activationState == .foregroundActive } as? UIWindowScene

                guard let activeScene else { return false }
                AppStore.requestReview(in: activeScene)
                return true
            #elseif canImport(StoreKit)
                SKStoreReviewController.requestReview()
                return true
            #else
                return false
            #endif
        }

        // Only consume the cooldown when there was a scene to ask in. `requestReview` itself
        // never reports whether the system actually showed anything, so a missing foreground
        // scene (the app backgrounded during the 2s prompt delay) is the one detectable failure —
        // previously it burned the timestamp and counter anyway, silencing prompts for the full
        // `daysLastReviewPassed` window without one ever having been shown.
        guard requested else {
            log.info("Review prompt skipped: no foreground-active scene to present in")
            return
        }

        @Dependency(\.telemetryService) var telemetryService
        await telemetryService.ratingBoosterPromptRequested()

        @Dependency(\.date) var date
        @Shared(.whenLastReviewShown) var reviewTimestamp
        @Shared(.successfulConnectionsSinceLastPrompt) var successfulConnectionsSinceLastPrompt
        $successfulConnectionsSinceLastPrompt.withLock { $0 = 0 }
        $reviewTimestamp.withLock { $0 = date.now }
    }

    /// Does nothing, and deliberately writes no shared state.
    ///
    /// ``ReviewFeature`` prompts from an effect that any store can start, since it listens to the app activation
    /// notification and to shared counters that other tests write. A test value that took the cooldown would write
    /// that shared state from whichever test happened to be running, and an exhaustive store watching for its own
    /// changes would report it. Tests that are about the prompt install a prompter of their own instead.
    static let testValue = ReviewPrompter {}
}

extension DependencyValues {
    var reviewPrompter: ReviewPrompter {
        get { self[ReviewPrompter.self] }
        set { self[ReviewPrompter.self] = newValue }
    }
}
