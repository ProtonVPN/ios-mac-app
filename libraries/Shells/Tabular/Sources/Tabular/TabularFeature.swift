//
//  Created on 28/07/2026.
//
//  Copyright (c) 2026 Proton AG
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

import CasePaths
import ComposableArchitecture
import Connection
import CoreGraphics
import Domain
import Home
import HomeShared
import Payments
import PaymentsShared
import VPNAppCore

/// The tabular app's shell, above the tabs. The globe and the connection status UI form the backdrop, and the
/// tabs sit over them in a sheet the user can raise and lower, so how much map is visible is shell state, not
/// any one tab's.
///
/// Home, Countries, Profiles and Settings remain ordinary tab pages. This reducer holds only the two children
/// that draw behind every page, plus the decisions that need the backdrop and a page at the same time. Sitting
/// above the tab features lets it take more of them as children later without any tab depending on the shell.
@Reducer
public struct TabularFeature {
    /// How far the sheet is raised, and with it how much of the globe shows. The same detent list serves every
    /// tab, declared in height order.
    public enum Detent: Equatable, CaseIterable {
        /// Minimized to its bar. The globe is effectively the screen, and the location pins are in hand.
        case bar
        /// Half the room: the page above, the globe centered on the connection below.
        case half
        /// Raised over the map.
        case full

        /// The bar detent's height, resolved above the bottom safe area
        static let barHeight: CGFloat = 100
    }

    /// Ordered as the tab bar presents them.
    public enum Tab: String, CaseIterable, Identifiable, Sendable {
        case home
        case countries
        case profiles
        case settings

        public var id: String {
            rawValue
        }
    }

    /// What the bar draws over a tab's glyph.
    public enum Badge: Equatable, Sendable {
        /// A packet capture is running.
        case recording
    }

    @ObservableState
    public struct State: Equatable {
        public internal(set) var detent: Detent = .half
        public internal(set) var tab: Tab = .home
        /// The tabs whose navigation stacks are currently pushed beyond their root. Whether the sheet is held at full
        /// depends on the visible tab, so that answer is computed from this set on demand; a stored flag would go stale
        /// on every tab switch.
        public internal(set) var deepTabs: Set<Tab> = []

        /// Whether the visible tab has moved into a menu. The legacy detail pages are still designed for the whole
        /// screen, so while one is up the sheet's only stop is full.
        public var isPageDeep: Bool {
            deepTabs.contains(tab)
        }

        /// The capture session, so the settings tab can display the recording badge.
        @SharedReader(.captureSession) public var captureSession: CaptureSession = .noSession

        /// The mark the bar shows over a tab's glyph, or nil for none. A packet capture in progress is the only badge
        /// today; it rides the settings tab because that is where a capture is stopped.
        public func badge(for tab: Tab) -> Badge? {
            guard tab == .settings else { return nil }
            return captureSession.isRunning ? .recording : nil
        }

        public var commands = ConnectionCommandsFeature.State()
        public var connectionStatus = ConnectionStatusFeature.State()
        public var home = HomeFeature.State()
        public var map = HomeMapFeature.State()

        /// The shell's own upsell, shown over whichever tab is up. The map, the status banner and the connection
        /// machinery draw behind or above every page, so their upsells cannot be a page's destination: a non-selected
        /// page is out of the hierarchy and a destination set on it would present nothing.
        @Presents public var payments: PaymentsMainFeature.State?

        /// The two-factor notice, a shell destination for the same reason as `payments`: the connection machinery
        /// runs above the tabs, so the notice can arrive while any tab is up.
        @Presents public var localAgentNotice: LocalAgentNoticeFeature.State?

        public init(detent: Detent = .half) {
            self.detent = detent
        }
    }

    public enum Action {
        case commands(ConnectionCommandsFeature.Action)
        case connectionStatus(ConnectionStatusFeature.Action)
        /// The sheet came to rest at a new detent, or a policy below moved it.
        case detentChanged(Detent)
        case home(HomeFeature.Action)
        case localAgentNotice(PresentationAction<LocalAgentNoticeFeature.Action>)
        case map(HomeMapFeature.Action)
        /// A tab's navigation depth changed: pushed beyond its root, or back at it.
        case pageDepthChanged(tab: Tab, isDeep: Bool)
        case payments(PresentationAction<PaymentsMainFeature.Action>)
        case tabSelected(Tab)
    }

    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.openCredentiallessSignUp) private var openCredentiallessSignUp

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.commands, action: \.commands) {
            ConnectionCommandsFeature()
        }
        Scope(state: \.connectionStatus, action: \.connectionStatus) {
            ConnectionStatusFeature()
        }
        Scope(state: \.map, action: \.map) {
            HomeMapFeature()
        }
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Reduce { state, action in
            switch action {
            case let .detentChanged(detent):
                // If a page is designed for the whole screen, don't let the user collapse the sheet.
                state.detent = state.isPageDeep ? .full : detent
                return .none

            case let .pageDepthChanged(tab, isDeep):
                if isDeep {
                    state.deepTabs.insert(tab)
                } else {
                    state.deepTabs.remove(tab)
                }
                // If the visible page is designed for the whole screen, don't let the user collapse the sheet.
                if state.isPageDeep {
                    state.detent = .full
                }
                return .none

            case let .tabSelected(tab):
                state.tab = tab
                if state.isPageDeep {
                    // The chosen tab was left in a detail page, which needs the whole sheet.
                    state.detent = .full
                } else if state.detent == .bar {
                    // Reading a page means raising the sheet off its bar.
                    state.detent = .half
                }
                return .none

            case let .map(.delegate(.connect(spec))):
                // Tapping a location pin connects through the same command pipeline as recents and the card, and drops
                // the sheet so the camera flight to the new country is viewable.
                state.detent = .bar
                connectionCommandClient.send(.connect(spec, nil, .map))
                return .none

            case .map(.mapMoved), .map(.mapBackgroundTapped):
                // Touching the map through the half sheet should make it interactive. Collapse the bar, which is
                // monitored elsewhere to make the pins become interactive.
                if state.detent == .half {
                    state.detent = .bar
                }
                return .none

            case .map(.delegate(.showUpsell)):
                state.payments = .init(upsellModalType: .allCountries)
                return .none

            case let .connectionStatus(.delegate(.upsellTapped(upsellMode))):
                let upsell: UpsellModalType = switch upsellMode {
                case .netshield: .netShield
                case .serverChange: .allCountries
                }
                state.payments = .init(upsellModalType: upsell)
                return .none

            case .commands(.commandReceived(.connect)):
                // A connect that starts under the fully raised sheet lowers it to half, so the status view and the
                // camera flight come into view without the user having to clear the sheet themselves.
                if state.detent == .full, !state.isPageDeep {
                    state.detent = .half
                }
                return .none

            case let .commands(.delegate(delegated)):
                switch delegated {
                case let .connectionFailed(error):
                    // The review-prompt signal lives in Home's tree, so the shell only routes. The error itself
                    // lands in the shared `lastConnectionError`, which any tab-independent reader can consume.
                    return .send(.home(.connectionFailed(error)))
                case let .intentResolutionFailed(resolutionError):
                    // Each way an intent can fail to resolve is a plan limitation, so each maps onto the
                    // upsell that lifts it.
                    state.payments = switch resolutionError {
                    case .secureCoreUnavailable:
                        .init(upsellModalType: .secureCore)
                    case let .specificCountryUnavailable(countryCode):
                        .init(upsellModalType: .country(countryCode: countryCode))
                    case let .serverChangeUnavailable(until, duration, exhaustedSkips):
                        .init(upsellModalType: .cantSkip(before: until, totalDuration: duration, longSkip: exhaustedSkips))
                    }
                    return .none
                case let .twoFactorRequired(error):
                    // The connection machinery runs above the tabs, so the notice presents from the shell,
                    // where it shows whichever tab is up.
                    state.localAgentNotice = .init(twoFactorError: error)
                    return .none
                }

            case .localAgentNotice(.presented(.disconnect)):
                state.localAgentNotice = nil
                connectionCommandClient.send(.disconnect(.fidoAuthentication))
                return .none

            case .payments(.presented(.delegate(.completed))),
                 .payments(.presented(.delegate(.dismissed))):
                state.payments = nil
                return .none

            case .payments(.presented(.delegate(.createAccountFirstRequested))):
                state.payments = nil
                return .run { @MainActor [openCredentiallessSignUp] _ in
                    openCredentiallessSignUp()
                }

            case .commands, .connectionStatus, .home, .localAgentNotice, .map, .payments:
                return .none
            }
        }
        .ifLet(\.$payments, action: \.payments) {
            PaymentsMainFeature()
        }
        .ifLet(\.$localAgentNotice, action: \.localAgentNotice) {
            LocalAgentNoticeFeature()
        }
    }
}
