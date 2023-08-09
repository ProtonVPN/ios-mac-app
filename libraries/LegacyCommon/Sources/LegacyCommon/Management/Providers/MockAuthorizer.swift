//
//  Created on 10/08/2023.
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
import Dependencies
import XCTestDynamicOverlay

public class MockFeatureAuthorizer: FeatureAuthorizer {
    var featureAuthorizationMap: [String: Bool] = [:]

    func registerAuthorization<T: AppFeature>(for feature: T.Type, to value: Bool) {
        let key = Self.key(for: feature)
        featureAuthorizationMap[key] = value
    }

    func registerAuthorization<T: AppFeature>(forSubFeature subFeature: T.SubFeature, of feature: T.Type, to value: Bool) {
        let key = Self.key(for: subFeature, of: feature)
        featureAuthorizationMap[key] = value
    }

    public func authorizer<T: AppFeature>(forSubFeatureOf feature: T.Type) -> (T.SubFeature) -> Bool {
        return { subFeature in
            let key = Self.key(for: subFeature, of: feature)
            guard let authorization = self.featureAuthorizationMap[key] else {
                XCTFail("Authorization requested for `\(subFeature)`, but no value was registered under key `\(key)`")
                return false
            }
            return authorization
        }
    }

    public func authorizer<T: AppFeature>(for feature: T.Type) -> () -> Bool {
        return {
            let key = Self.key(for: feature)
            guard let authorization = self.featureAuthorizationMap[key] else {
                XCTFail("Authorization requested for `\(feature)`, but no value was registered under key `\(key)`")
                return false
            }
            return authorization
        }
    }

    private static func key<T: AppFeature>(for feature: T.Type) -> String {
        "\(feature)"
    }

    private static func key<T: AppFeature>(for subFeature: T.SubFeature, of feature: T.Type) -> String {
        "\(key(for: feature)).\(subFeature)"
    }
}
