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

    @MainActor static var liveValue = ReviewPrompter {
        @Shared(.whenLastReviewShown) var reviewTimestamp
        @Shared(.successfulConnectionsSinceLastPrompt) var successfulConnectionsSinceLastPrompt
        @Dependency(\.date) var date
        #if canImport(UIKit) && canImport(StoreKit)
            let activeScene = UIApplication.shared
                .connectedScenes
                .first { $0.activationState == .foregroundActive } as? UIWindowScene

            activeScene.map { AppStore.requestReview(in: $0) }

        #elseif canImport(StoreKit)
            SKStoreReviewController.requestReview()
        #endif

        @Dependency(\.telemetryService) var telemetryService
        await telemetryService.ratingBoosterPromptRequested()
        $successfulConnectionsSinceLastPrompt.withLock { $0 = 0 }
        $reviewTimestamp.withLock { $0 = date.now }
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
            @Shared(.successfulConnectionsSinceLastPrompt) var successfulConnectionsSinceLastPrompt
            $reviewTimestamp.withLock { $0 = date.now }
            $successfulConnectionsSinceLastPrompt.withLock { $0 = 0 }
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
