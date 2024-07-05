//
//  Created on 22/04/2024.
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

import ComposableArchitecture
import Dependencies

import ProtonCoreForceUpgrade
import ProtonCoreNetworking
import ProtonCoreServices

import CommonNetworking
import CertificateAuthentication // VPN Auth Keychain
import VPNShared
import VPNAppCore

/// Platform independent reducer without UI, responsible for session management.
/// This reducer is meant to be composed with main app features, at the top level of the app. Children of the top level
/// app feature can pass delegate actions like logout, at which point the top level feature send the appropriate
/// `SessionNetworkingFeature.Action`.
///
/// See `AppFeature` for more information.
struct SessionNetworkingFeature: Reducer {
    enum State: Equatable {
        /// No session. Not to be confused with authenticated using an unauth session.
        case unauthenticated(SessionFetchingError?)
        /// Session information is being fetched from the keychain, or new unauth session is being acquired.
        case acquiringSession
        /// Can contain auth or unauth session
        case authenticated(CommonNetworking.Session)
    }

    @CasePathable
    enum Action {
        case startLogout
        case startAcquiringSession
        case sessionFetched(Result<SessionAcquiringResult, Error>)
        case forkedSessionAuthenticated(Result<AuthCredentials, Error>)
        case sessionExpired
        case userTierRetrieved(Int, CommonNetworking.Session)
        case userDisplayNameRetrieved(String?)
    }

    @Dependency(\.networking) var networking
    @Dependency(\.networkingDelegate) var networkingDelegate
    @Dependency(\.authKeychain) var authKeychain
    @Dependency(\.unauthKeychain) var unauthKeychain
    @Dependency(\.vpnAuthenticationStorage) var vpnAuthStorage

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startLogout:
                authKeychain.clear()
                vpnAuthStorage.deleteKeys()
                return .run { send in await send(.startAcquiringSession) }

            case .startAcquiringSession:
                state = .acquiringSession
                return .run { send in
                    await send(.sessionFetched(Result { try await networking.acquireSessionIfNeeded() }))
                }

            case .sessionFetched(.success(.sessionAlreadyPresent(let credentials))),
                    .sessionFetched(.success(.sessionFetchedAndAvailable(let credentials))):
                // Credentials already stored in keychain by Networking implementation in CommonNetworking
                let session: CommonNetworking.Session = credentials.isForUnauthenticatedSession
                    ? .unauth(uid: credentials.sessionID)
                    : .auth(uid: credentials.sessionID)
                state = .authenticated(session)
                return .run { send in
                    // we have a session, now get the user tier
                    let userTier = try await networking.userTier
                    await send(.userTierRetrieved(userTier, session))
                } catch: { error, send in
                    log.debug("Couldn't retrieve user tier after user already logged in in the previous session, ignoring", category: .api)
                }

            case .sessionFetched(.success(.sessionUnavailableAndNotFetched)):
                state = .unauthenticated(.sessionUnavailable)
                return .none

            case .sessionFetched(.failure(let error)):
                state = .unauthenticated(.network(internalError: error))
                return .none

            case .sessionExpired:
                state = .unauthenticated(nil)
                return .send(.startLogout)

            case .forkedSessionAuthenticated(.success(let credentials)):
                // We forked a session ourselves, and web client just authenticated it
                let session = Session.auth(uid: credentials.sessionId)
                try? authKeychain.store(credentials)
                return .run { send in
                    // we have a session, now get the user tier
                    let (userTier, userDisplayName) = try await (networking.userTier, networking.userDisplayName)
                    _ = await (
                        send(.userTierRetrieved(userTier, session)),
                        send(.userDisplayNameRetrieved(userDisplayName))
                    )
                    // let's listen to logout events
                    for await authenticated in networkingDelegate.sessionAuthenticatedEvents where !authenticated {
                        await send(.sessionExpired)
                    }
                } catch: { error, send in
                    await send(.startLogout)
                }
            case .userTierRetrieved(let tier, let session):
                // TODO: This is an additional step before logging user in, when we'll start to support free users, we can remove this code
                if tier > 0 {
                    state = .authenticated(session)
                    networking.setSession(session)
                    unauthKeychain.clear()
                    return .none
                } else {
                    return .run { send in
                        await send(.startLogout) // tier detected to be free, log the user out
                    }
                }
            case .userDisplayNameRetrieved:
                return .none
            case .forkedSessionAuthenticated(.failure):
                return .none
            }
        }
    }
}

enum SessionFetchingError: Error, Equatable {
    case sessionUnavailable
    case network(internalError: Error)

    static func == (lhs: SessionFetchingError, rhs: SessionFetchingError) -> Bool {
        switch (lhs, rhs) {
        case (.sessionUnavailable, .sessionUnavailable):
            return true
        case (.network, .network):
            return true
        default:
            return false
        }
    }
}
