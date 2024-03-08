//
//  Created on 21/08/2023.
//
//  Copyright (c) 2023 Proton AG
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

/// Defines the requirements for a feature that can be managed by the generic `AppFeaturePropertyProviderProtocol`
///
/// Implement `AppFeature`'s interace to control whether the feature should be hidden from the user, displayed
/// as requiring an upgrade, or interactive, based on the static `canUse` function.
///
/// Implementation of `ModularAppFeature` along with `StorableFeature` define how the feature's value will be stored.
/// For backwards compatibility, StorableFeature defines a typealias `LegacyStorageType` along with an initialiser from
/// this type.
///
/// - Note: Check `VPNAccelerator` for implementation ideas.
public typealias ProvidableFeature = AppFeature & ModularAppFeature & StorableFeature & DefaultableFeature

public protocol DefaultableFeature {
    static func defaultValue(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> Self
}

public protocol StorableFeature: Codable {
    /// Backwards compatibility allowing `AppFeaturePropertyProviderProtocol` to load global settings values (as
    /// opposed user-specific) for this feature stored with a potentially different representation by older app
    /// versions. This old value should be deleted after being loaded for the first user it is requested for,
    /// otherwise it will act as an incorrect default value for other users.
    ///
    /// By default, `LegacyStorageType` is set to `Void`, where no attempt is made to migrate using legacy values from
    /// storage.
    associatedtype LegacyStorageType = Void

    /// Conversion from the optional `LegacyStorageType`. When nil, no attempt it made to migrate using legacy values in
    /// storage.
    static var legacyConversion: ((LegacyStorageType) -> Self)? { get }

    static var storageKey: String { get }

    /// notification sent whenever the current value changes
    static var notificationName: Notification.Name? { get }

}

extension StorableFeature where LegacyStorageType == Void {
    public static var legacyConversion: ((LegacyStorageType) -> Self)? { nil }
}

/// Helper protocol that simplifies display/interaction logic in the view and business layers by enabling generic
/// handling of features, such that they can be displayed as e.g. an array of switches.
public protocol ToggleableFeature: Equatable {
    static var off: Self { get }
    static var on: Self { get }
}
