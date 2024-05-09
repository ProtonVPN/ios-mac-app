//
//  Created on 01/05/2024.
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

import Dependencies
import XCTestDynamicOverlay

import ProtonCoreServices
import ProtonCoreNetworking

public protocol VPNNetworking {
    func acquireSessionIfNeeded() async throws -> SessionAcquiringResult
    func set(session: Session)
    func perform<T: Decodable>(request: Request) async throws -> T
}

public struct CoreNetworkingWrapper: VPNNetworking {
    
    public func acquireSessionIfNeeded() async throws -> SessionAcquiringResult {
        try await withCheckedThrowingContinuation { continuation in
            wrapped.apiService.acquireSessionIfNeeded { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func set(session: Session) {
        wrapped.apiService.setSessionUID(uid: session.uid)
    }
    
    let wrapped: Networking

    public func perform<T: Decodable>(request: Request) async throws -> T {
        try await wrapped.perform(request: request)
    }
}

/// If using this dependency, make sure `liveValue` owns the only `CoreNetworking` instance.
public enum VPNNetworkingKey: DependencyKey {
    public static var liveValue: VPNNetworking {
        @Dependency(\.authKeychain) var authKeychain
        @Dependency(\.unauthKeychain) var unauthKeychain
        @Dependency(\.appInfo) var appInfo
        @Dependency(\.networkingDelegate) var networkingDelegate

        #if TLS_PIN_DISABLE
        let pinAPIEndpoints = false
        #else
        let pinAPIEndpoints = true
        #endif

        let networking = CoreNetworking(
            delegate: networkingDelegate,
            appInfo: appInfo,
            authKeychain: authKeychain,
            unauthKeychain: unauthKeychain,
            pinApiEndpoints: pinAPIEndpoints
        )

        return CoreNetworkingWrapper(wrapped: networking)
    }
}

extension DependencyValues {
    public var networking: VPNNetworking {
        get { self[VPNNetworkingKey.self] }
        set { self[VPNNetworkingKey.self] = newValue }
    }
}
