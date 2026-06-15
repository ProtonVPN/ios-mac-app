//
//  Created on 18/08/2023.
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

import Dependencies
import Domain
import Foundation

// Display state for toggleable features
public enum PaidFeatureDisplayState: Equatable {
    /// Feature should be shown as available
    /// - parameters:
    ///   - enabled: The current value of the feature (on/off)
    ///   - interactive: Whether the user is able to turn the feature on/off
    case available(enabled: Bool, interactive: Bool)

    /// Feature should be shown as requiring an upgrade
    case upsell

    /// Don't display any UI. Feature disabled by feature flags or OS version
    case disabled
}

/// Derives the ``PaidFeatureDisplayState`` for a feature from its authorization result.
///
/// Consolidates the logic that was previously duplicated across the iOS and macOS settings view
/// models (`displayState(for:)`, `natDisplayState`, `moderateNATState`: the
/// authorization → display-state mapping is identical; only the "currently enabled" value differs,
/// so it's supplied by the caller via `isEnabled` (evaluated lazily, only when authorized).
public func paidFeatureDisplayState(
    for feature: (some AppFeature).Type,
    isEnabled: @autoclosure () -> Bool
) -> PaidFeatureDisplayState {
    @Dependency(\.featureAuthorizerProvider) var featureAuthorizerProvider
    let authorizer: () -> FeatureAuthorizationResult = featureAuthorizerProvider.authorizer(for: feature)
    switch authorizer() {
    case .success:
        return .available(enabled: isEnabled(), interactive: true)
    case .failure(.featureDisabled):
        return .disabled
    case .failure(.requiresUpgrade):
        return .upsell
    }
}

/// Convenience for a simple on/off feature: the enabled state is the feature's stored value.
public func paidFeatureDisplayState(
    for feature: (some ProvidableFeature & ToggleableFeature & Sendable).Type
) -> PaidFeatureDisplayState {
    paidFeatureDisplayState(for: feature, isEnabled: featureValue(for: feature) == .on)
}
