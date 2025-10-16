//
//  Created on 21/07/2025 by adam.
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

import Dependencies
import Sharing

extension SharedKey {
    /// Returns a ``FeatureSharedKey`` with the provided feature type.
    ///
    /// Example: @Shared(.feature(HermesFeature.self)) var hermesFeature = .off
    ///
    /// - Parameter featureType: The feature type you want to retrieve & set.
    /// - Returns: A ``FeatureSharedKey`` that could be used with an `@Shared` property.
    static func feature<Feature>(
        _ featureType: Feature.Type
    ) -> Self where Self == FeatureSharedKey<Feature>, Feature: ProvidableFeature {
        FeatureSharedKey(featureType: featureType)
    }
}

/// A Shared Key based on a ``ProvidableFeature``.
public final class FeatureSharedKey<Value>: SharedKey where Value: ProvidableFeature {
    public var id: some Hashable { featureType.storageKey }

    let featureType: Value.Type

    private let appFeaturePropertyProvider: Dependency<any AppFeaturePropertyProvider>

    init(featureType: Value.Type) {
        self.featureType = featureType
        self.appFeaturePropertyProvider = .init(\.appFeaturePropertyProvider)
    }

    public func load(context _: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        let value = appFeaturePropertyProvider.wrappedValue.getValue(for: featureType)
        continuation.resume(with: .success(value))
    }

    public func subscribe(
        context _: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        let stream = appFeaturePropertyProvider.wrappedValue.stream(for: featureType)
        let task = Task {
            for await value in stream {
                try Task.checkCancellation()
                subscriber.yield(value)
            }
        }
        return SharedSubscription {
            task.cancel()
        }
    }

    public func save(_ value: Value, context _: Sharing.SaveContext, continuation: Sharing.SaveContinuation) {
        continuation.resume(
            with: Result { appFeaturePropertyProvider.wrappedValue.setValue(value) }
        )
    }
}
