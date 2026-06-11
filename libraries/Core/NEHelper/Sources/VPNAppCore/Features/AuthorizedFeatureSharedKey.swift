//
//  Created on 10/06/2026 by Max Kupetskyi.
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

import Domain
import Foundation
import Sharing

/// A `SharedKey` exposing a `ProvidableFeature`'s *effective* (authorized) value through `@Shared`.
///
/// Reads return the clamped value (`AuthorizedFeatureValue.value()`); writes persist the raw user
/// value; observation re-derives on `UserDefaults` changes. This replaces the previous
/// `FeatureSharedKey` (which wrapped the removed `AppFeaturePropertyProvider`).
public final class AuthorizedFeatureSharedKey<Value: ProvidableFeature & Sendable>: SharedKey {
    private let feature: AuthorizedFeatureValue<Value>

    public var id: some Hashable {
        Value.storageKey
    }

    public init() {
        self.feature = AuthorizedFeatureValue<Value>()
    }

    public func load(context _: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        continuation.resume(returning: feature.value())
    }

    public func subscribe(
        context _: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        let task = Task { [feature] in
            for await value in feature.valueStream() {
                try Task.checkCancellation()
                subscriber.yield(value)
            }
        }
        return SharedSubscription { task.cancel() }
    }

    public func save(_ value: Value, context _: SaveContext, continuation: SaveContinuation) {
        feature.setValue(value)
        continuation.resume()
    }
}
