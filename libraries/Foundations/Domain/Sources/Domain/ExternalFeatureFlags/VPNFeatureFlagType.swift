//
//  Created on 2024-02-09.
//
//  Copyright (c) 2024 Proton AG
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
import ProtonCoreFeatureFlags

/// Feature flag types used across all VPN app platforms (iOS, macOS, etc.).
/// Used with ProtonCore FeatureFlags package:
/// `FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.sentry)`
///
///
/// This enum has to conform to `FeatureFlagTypeProtocol`.  Ideally we should
/// get rid of depending on ProtonCore in this package. In that case, conformance to
/// `FeatureFlagTypeProtocol` can be moved to the apps themselves leaving
/// only enum here.
///
/// Keep in mind that external feature flags update their values only after app restart.
public enum VPNFeatureFlagType: String, FeatureFlagTypeProtocol {

    /// Enable or disable Sentry integration. If disabled, SentryHelper.default instance
    /// will be nil, thus calls to it will do nothing.
    case sentry = "Sentry"

    /// Defines if we should exclude full sentry event metadata. Should be disabled
    /// (and can be deleted completely) only after INFSUP-682 is done.
    case sentryExcludeMetadata = "SentryExcludeMetadata"
}
