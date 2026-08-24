//
//  Created on 30/07/2026 by Max Kupetskyi.
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

// MARK: - Full server list refresh policy

/// Tracks how many times in a row the server list has been refreshed, so we know when to ask the API for the full
/// server list instead of one capped at the user's tier.
public extension ServerRepository {
    /// How often the full server list is fetched, counted in successful refreshes.
    static let fullServerListRefreshInterval = 10

    /// Number of consecutive successful server list refreshes, wrapping at ``fullServerListRefreshInterval``.
    var consecutiveSuccessfulRefreshes: Int {
        guard let storedValue = getMetadata(.consecutiveSuccessfulRefreshes) else {
            return 0
        }
        guard let existingRefreshes = Int(storedValue) else {
            log.debug("Stored value is not an Int", category: .persistence, metadata: ["value": "\(storedValue)"])
            return 0
        }
        return existingRefreshes
    }

    /// Whether the stored server names are already translated into `language`.
    func translationsAreCurrent(in language: String) -> Bool {
        getMetadata(.translationsLanguage) == language
    }

    /// Whether the next logicals request should ask for the full server list rather than one capped at the user's tier.
    /// The full server list is fetched every ``fullServerListRefreshInterval``-th time.
    func shouldFetchFullServerList(language: String) -> Bool {
        (consecutiveSuccessfulRefreshes % Self.fullServerListRefreshInterval) == 0
            || !translationsAreCurrent(in: language)
    }

    /// Advances the refresh counter, wrapping back to zero on every ``fullServerListRefreshInterval``-th refresh.
    func recordSuccessfulRefresh() {
        let refreshes = (consecutiveSuccessfulRefreshes + 1) % Self.fullServerListRefreshInterval
        setMetadata(String(refreshes), for: .consecutiveSuccessfulRefreshes)
    }

    /// Resets the refresh counter so that the next refresh fetches the full server list.
    ///
    /// Called when a refresh fails, since a partial list capped at the user's tier is only safe to request on top of an
    /// up to date database.
    func resetSuccessfulRefreshes() {
        setMetadata(String(0), for: .consecutiveSuccessfulRefreshes)
    }
}

// MARK: - Conditional requests

public extension DatabaseMetadata.Key {
    /// Where the `If-Modified-Since` timestamp of the last logicals response for `scope` is kept
    static func lastModified(for scope: ServerListScope) -> Self {
        switch scope {
        case .allTiers: .lastModifiedAll
        case .freeTier: .lastModifiedFree
        case .guestSession: .lastModifiedGuest
        }
    }
}

public extension ServerRepository {
    /// The scope a logicals request should use, given the `requested` one and the `language` it asks in.
    ///
    /// A language change makes every stored name out of date, not just the free ones. A response capped at the
    /// free tier would leave the paid servers named in the old language, so the request widens to every tier.
    func logicalsRequestScope(for requested: ServerListScope, language: String) -> ServerListScope {
        translationsAreCurrent(in: language) ? requested : requested.coveringEveryTier
    }

    /// The `If-Modified-Since` baseline for a logicals request for `scope` made in `language`.
    ///
    /// A language change makes every stored translated name out of date, so there is no baseline to request
    /// against and the response arrives in full.
    func logicalsRequestBaseline(scope: ServerListScope, language: String) -> String? {
        guard translationsAreCurrent(in: language) else {
            return nil
        }
        return getMetadata(.lastModified(for: scope))
    }

    /// Records that the stored servers are a copy of `scope` as of `lastModifiedAt`.
    ///
    /// A full account response is a valid baseline for a subsequent free tier request too, so it
    /// counts for both
    func recordServerList(scope: ServerListScope, lastModifiedAt: String) {
        setMetadata(lastModifiedAt, for: .lastModified(for: scope))
        if scope == .allTiers {
            setMetadata(lastModifiedAt, for: .lastModified(for: .freeTier))
        }
    }

    /// Forgets which server list the database holds a copy of
    func deleteServerListBaseline() {
        for scope in ServerListScope.allCases {
            deleteMetadata(for: .lastModified(for: scope))
        }
    }
}
