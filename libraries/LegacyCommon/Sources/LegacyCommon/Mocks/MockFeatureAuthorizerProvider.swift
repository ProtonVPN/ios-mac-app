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

#if DEBUG
    import Dependencies
    import Foundation
    import IssueReporting

    public class MockFeatureAuthorizerProvider: FeatureAuthorizerProvider {
        var featureAuthorizationMap: [String: FeatureAuthorizationResult] = [:]

        func registerAuthorization(
            for feature: (some AppFeature).Type,
            to value: FeatureAuthorizationResult
        ) {
            let key = Self.key(for: feature)
            featureAuthorizationMap[key] = value
        }

        func registerAuthorization(
            forSubFeature subFeature: some ModularAppFeature,
            to value: FeatureAuthorizationResult
        ) {
            let key = Self.key(for: subFeature)
            featureAuthorizationMap[key] = value
        }

        public func authorizer(
            for feature: (some AppFeature).Type
        ) -> () -> FeatureAuthorizationResult {
            let key = Self.key(for: feature)
            return {
                guard let authorization = self.featureAuthorizationMap[key] else {
                    reportIssue("Authorization requested for `\(feature)`, but no value was registered under key `\(key)`")
                    return .failure(.requiresUpgrade)
                }
                return authorization
            }
        }

        public func authorizer<T: ModularAppFeature>(
            forSubFeatureOf _: T.Type
        ) -> (T) -> FeatureAuthorizationResult {
            { subFeature in
                let key = Self.key(for: subFeature)
                guard let authorization = self.featureAuthorizationMap[key] else {
                    reportIssue("Authorization requested for `\(subFeature)`, but no value was registered under key `\(key)`")
                    return .failure(.requiresUpgrade)
                }
                return authorization
            }
        }

        public func authorizer<T: ModularAppFeature>(
            for _: T.Type
        ) -> Authorizer<T> {
            Authorizer(canUse: { subFeature in
                let key = Self.key(for: subFeature)
                guard let authorization = self.featureAuthorizationMap[key] else {
                    reportIssue("Authorization requested for `\(subFeature)`, but no value was registered under key `\(key)`")
                    return .failure(.requiresUpgrade)
                }
                return authorization
            })
        }

        private static func key(for feature: (some AppFeature).Type) -> String {
            "\(feature)"
        }

        private static func key<T: ModularAppFeature>(for subFeature: T) -> String {
            "\(T.self).\(subFeature)"
        }
    }

    public struct ConstantFeatureAuthorizerProvider: FeatureAuthorizerProvider {
        let result: FeatureAuthorizationResult

        public init(result: FeatureAuthorizationResult) {
            self.result = result
        }

        public func authorizer(for _: (some AppFeature).Type) -> () -> FeatureAuthorizationResult {
            { result }
        }

        public func authorizer<T: ModularAppFeature>(forSubFeatureOf _: T.Type) -> (T) -> FeatureAuthorizationResult {
            { _ in result }
        }

        public func authorizer<T: ModularAppFeature>(for _: T.Type) -> Authorizer<T> {
            .init(canUse: { _ in result })
        }
    }
#endif
