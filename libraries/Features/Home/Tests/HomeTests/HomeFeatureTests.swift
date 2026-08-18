//
//  Created on 12/08/2026 by Max Kupetskyi.
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

import Announcement
import ComposableArchitecture
import Connection
import Domain
import DomainTestSupport
import Foundation
@testable import HomeShared
import Localization
import PaymentsShared
import Persistence
import PersistenceTestSupport
import Strings
import Testing
import VPNAppCore

/// Covers the decisions the home screen makes itself: which modal it presents, which connection
/// command it sends, and when a modal goes away again. The child features own everything else.
@MainActor
@Suite("Home feature", .serialized)
struct HomeFeatureTests {
    // The tier, the connection, the last connection error, the recents and the default connection
    // preference are process-wide shared state, so the suite runs serialized and every test starts
    // from the same baseline: a free user who is disconnected and has never connected.
    @Shared(.userTier) private var userTier: VpnTier?
    @Shared(.connectionState) private var connectionState: ConnectionState
    @Shared(.lastConnectionError) private var lastConnectionError: ConnectionError?
    @Shared(.recentConnections) private var recentConnections
    @Shared(.storedDefaultConnectionPreference) private var defaultConnectionPreference: DefaultConnectionPreference?

    init() {
        $userTier.withLock { $0 = .free }
        $connectionState.withLock { $0 = .disconnected }
        $lastConnectionError.withLock { $0 = nil }
        // `RecentsFeature.State` writes an empty list on init when it finds none, and a store must
        // not change shared state before the first action is even sent.
        $recentConnections.withLock { $0 = [] }
        $defaultConnectionPreference.withLock { $0 = .fastest }
    }

    // MARK: - Upsell

    #if os(iOS)
        /// A guest has to create an account before they can pay, and the sign-up screen is presented
        /// over whatever is on screen at that moment. The upsell therefore stays up: dismissing it in
        /// the same step leaves the sign-up flow anchored to a controller that is disappearing, and
        /// the guest ends up on the home screen with nothing presented.
        @Test("Asking a guest to create an account leaves the upsell on screen")
        func createAccountRequestKeepsTheUpsellPresented() async {
            let signUps = LockIsolated(0)
            let store = makeStore(destination: .payments(.init(upsellModalType: .allCountries))) {
                $0.openCredentiallessSignUp = { signUps.withValue { $0 += 1 } }
            }

            await store.send(.destination(.presented(.payments(.delegate(.createAccountFirstRequested)))))
            await store.finish()

            #expect(signUps.value == 1)
            #expect(store.state.destination?.is(\.payments) == true)
        }
    #endif

    @Test("A completed purchase closes the upsell")
    func completedPurchaseClosesTheUpsell() async {
        let store = makeStore(destination: .payments(.init(upsellModalType: .allCountries)))

        await store.send(.destination(.presented(.payments(.delegate(.completed))))) {
            $0.destination = nil
        }
    }

    @Test("Dismissing the upsell closes it")
    func dismissedUpsellClosesTheUpsell() async {
        let store = makeStore(destination: .payments(.init(upsellModalType: .allCountries)))

        await store.send(.destination(.presented(.payments(.delegate(.dismissed))))) {
            $0.destination = nil
        }
    }

    @Test(
        "Each recents banner opens its own upsell",
        arguments: zip(
            BannerType.allCases,
            [
                UpsellModalType.allCountries,
                .vpnAccelerator,
                .streaming,
                .netShield,
                .secureCore,
                .p2pSupport,
                .devices,
                .torOverVPN,
                .customization,
            ]
        )
    )
    func recentsBannerOpensItsUpsell(bannerType: BannerType, modalType: UpsellModalType) async {
        let store = makeStore()

        await store.send(.recents(.delegate(.upsellTapped(bannerType)))) {
            $0.destination = .payments(.init(upsellModalType: modalType))
        }
    }

    // MARK: - Free connections

    @Test("Tapping the card while disconnected offers a free user the countries they can reach")
    func cardTapOffersTheFreeCountries() async {
        let store = makeStore {
            var repository = ServerRepository.notEmpty()
            // The same country twice: the list the user sees holds one entry per country.
            repository.servers = { _, _ in [Self.freeServer, Self.freeServer] }
            $0.serverRepository = repository
        }

        await store.send(.connectionCard(.delegate(.tapAction))) {
            $0.destination = .freeConnectionsInfo(.init(countries: [
                .init(
                    code: Logical.mock.exitCountryCode,
                    name: LocalizationUtility.default.countryName(forCode: Logical.mock.exitCountryCode)
                        ?? Localizable.unavailable
                ),
            ]))
        }
    }

    @Test("Tapping the card while disconnected does nothing for a paid user")
    func cardTapIsInertForPaidUsers() async {
        $userTier.withLock { $0 = .paid }
        let store = makeStore()

        await store.send(.connectionCard(.delegate(.tapAction)))
    }

    @Test("Upgrading from the free countries list swaps in the upsell")
    func freeCountriesUpgradeOpensTheUpsell() async {
        let store = makeStore(destination: .freeConnectionsInfo(.mock))

        await store.send(.destination(.presented(.freeConnectionsInfo(.upgradeTapped)))) {
            $0.destination = .payments(.init(upsellModalType: .allCountries))
        }
    }

    @Test("Dismissing the free countries list closes it")
    func freeCountriesDismissClosesTheList() async {
        let store = makeStore(destination: .freeConnectionsInfo(.mock))

        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
    }

    // MARK: - Connection details

    @Test("Tapping the card while connected opens the connection details")
    func cardTapOpensTheConnectionDetails() async throws {
        $connectionState.withLock { $0 = Self.connected }
        let details = try #require(Self.connected.connectionScreenFeatureState())
        let store = makeStore()

        await store.send(.connectionCard(.delegate(.tapAction))) {
            $0.destination = .connectionDetails(details)
        }
    }

    // MARK: - Connection commands

    @Test("The card's connect and disconnect buttons report the connection card as the trigger")
    func cardButtonsReportTheConnectionCardTrigger() async {
        let commands = LockIsolated<[RecordedCommand]>([])
        let store = makeStore { $0.recordCommands(into: commands) }

        await store.send(.connectionCard(.delegate(.connect(.defaultFastest))))
        await store.send(.connectionCard(.delegate(.disconnect)))

        #expect(commands.value == [.connect(.defaultFastest, .connectionCard), .disconnect(.connectionCard)])
    }

    @Test("Connecting from the recents list reports the pin or the recent trigger", arguments: [false, true])
    func recentConnectReportsItsOwnTrigger(isPinned: Bool) async {
        let commands = LockIsolated<[RecordedCommand]>([])
        let store = makeStore { $0.recordCommands(into: commands) }

        await store.send(.recents(.delegate(.connect(.defaultFastest, isPinned: isPinned))))

        #expect(commands.value == [.connect(.defaultFastest, isPinned ? .pin : .recent)])
    }

    @Test("A failed connection is handed to the shared properties feature")
    func connectionFailureIsForwarded() async {
        let store = makeStore()

        // The forwarded action is handled before `send` returns, so the shared error it stores shows
        // up here rather than on the action the store receives.
        await store.send(.connectionFailed(.intentMissing)) {
            $0.sharedProperties.$lastConnectionError.withLock { $0 = .intentMissing }
        }
        await store.receive(\.sharedProperties.connectionFailed)
        await store.receive(\.sharedProperties.review.connectionFailed)
    }

    // MARK: - Change Server

    @Test("Change Server connects to a random server when the user is allowed one")
    func changeServerConnectsWhenTheUserIsAllowedOne() async {
        let commands = LockIsolated<[RecordedCommand]>([])
        let store = makeStore {
            $0.serverChangeAuthorizer = .init(
                serverChangeAvailability: { .available },
                registerServerChangeAtDate: { _ in }
            )
            $0.recordCommands(into: commands)
        }

        await store.send(.connectionCard(.delegate(.changeServerButtonTapped)))
        await store.receive(\.changeServer)

        #expect(commands.value == [.connect(Self.randomServer, .changeServer)])
    }

    @Test("Change Server shows the cooldown modal while the user has to wait")
    func changeServerShowsTheCooldownModal() async {
        let commands = LockIsolated<[RecordedCommand]>([])
        let store = makeStore {
            $0.serverChangeAuthorizer = .init(
                serverChangeAvailability: { Self.cooldown },
                registerServerChangeAtDate: { _ in }
            )
            $0.recordCommands(into: commands)
        }

        await store.send(.connectionCard(.delegate(.changeServerButtonTapped))) {
            $0.destination = .changeServer(.init(serverChangeAvailability: Self.cooldown))
        }

        #expect(commands.value.isEmpty)
    }

    @Test("Changing the server from the cooldown modal closes it and connects")
    func changeServerFromTheModalClosesItAndConnects() async {
        let commands = LockIsolated<[RecordedCommand]>([])
        let store = makeStore(destination: .changeServer(.init(serverChangeAvailability: .available))) {
            $0.serverChangeAuthorizer = .init(
                serverChangeAvailability: { .available },
                registerServerChangeAtDate: { _ in }
            )
            $0.recordCommands(into: commands)
        }

        await store.send(.destination(.presented(.changeServer(.changeServerButtonTapped)))) {
            $0.destination = nil
        }
        await store.receive(\.changeServer)

        #expect(commands.value == [.connect(Self.randomServer, .changeServer)])
    }

    @Test("A server change nobody authorized sends no command")
    func unauthorizedChangeServerSendsNoCommand() async {
        // The authorizer's test value refuses every change.
        let commands = LockIsolated<[RecordedCommand]>([])
        let store = makeStore { $0.recordCommands(into: commands) }

        await store.send(.changeServer)

        #expect(commands.value.isEmpty)
    }

    /// Both modals are presented from the same place, so the upsell can only go up once the cooldown
    /// modal reports that it has gone. The feature remembers the tap until then.
    @Test("Upgrading from the cooldown modal opens the upsell once that modal has gone")
    func cooldownUpgradeOpensTheUpsellAfterTheModalHasGone() async {
        let store = makeStore(destination: .changeServer(.init(serverChangeAvailability: Self.cooldown)))
        // The feature keeps the pending tap in a fileprivate flag, which a test cannot name.
        store.exhaustivity = .off

        await store.send(.destination(.presented(.changeServer(.upgradeButtonTapped))))
        #expect(store.state.destination == nil)

        await store.send(.didDismissChangeServer)
        #expect(store.state.destination?.payments?.upsellModalType == .allCountries)
    }

    @Test("Dismissing the cooldown modal without upgrading leaves the screen alone")
    func cooldownDismissWithoutUpgradingPresentsNothing() async {
        let store = makeStore()

        await store.send(.didDismissChangeServer)
    }

    // MARK: - Default connection

    @Test("The card header opens the default connection picker, and picking a preference closes it")
    func defaultConnectionPickerOpensAndCloses() async {
        let store = makeStore()

        await store.send(.connectionCard(.delegate(.defaultConnectionTapped))) {
            $0.destination = .defaultConnection(.init())
        }
        await store.send(.destination(.presented(.defaultConnection(.preferenceSelected(.mostRecent))))) {
            $0.destination?.defaultConnection?.$defaultConnectionPreference.withLock { $0 = .mostRecent }
            $0.destination = nil
        }
    }

    // MARK: - What's new

    @Test("A what's new item is presented, and dismissing it closes the sheet")
    func whatsNewItemIsPresentedAndDismissed() async {
        let store = makeStore()

        await store.send(.whatsNewChecker(.show(items: [.widgetAdoption]))) {
            $0.destination = .whatsNew(.init(item: .widgetAdoption))
        }
        await store.send(.destination(.presented(.whatsNew(.dismissItem)))) {
            $0.destination = nil
        }
    }

    // MARK: - Packet capture

    @Test("A finished packet capture presents the capture sheet, and the next capture closes it")
    func finishedCapturePresentsAndClosesTheSheet() async {
        let store = makeStore()

        await store.send(.newCaptureSession(.sessionEnded(urlWithSize: Self.capturedFile))) {
            $0.destination = .sessionCaptured(.init())
        }
        await store.send(.newCaptureSession(.noSession)) {
            $0.destination = nil
        }
    }

    @Test("A new packet capture leaves an unrelated modal alone")
    func newCaptureLeavesUnrelatedModalsAlone() async {
        let store = makeStore(destination: .payments(.init(upsellModalType: .allCountries)))

        await store.send(.newCaptureSession(.noSession))
    }

    // MARK: - Announcements

    @Test("Announcements are refreshed only while the polling flag is on", arguments: [false, true])
    func announcementRefreshFollowsThePollingFlag(pollingEnabled: Bool) async {
        @Shared(.featureFlags) var featureFlags
        $featureFlags.withLock { $0 = pollingEnabled ? .allEnabled : .allDisabled }
        let refreshes = LockIsolated(0)
        let store = makeStore {
            $0.announcementRefresher = AnnouncementRefresher(
                tryRefreshing: { refreshes.withValue { $0 += 1 } },
                clear: {}
            )
        }

        await store.send(.refreshAnnouncementsIfNeeded).finish()

        #expect(refreshes.value == (pollingEnabled ? 1 : 0))
    }

    // MARK: - Fixtures

    private static let now = Date(timeIntervalSince1970: 1_754_000_000)

    private static let randomServer = ConnectionSpec(location: .any(.random), features: [])

    private static let cooldown = ServerChangeAuthorizer.ServerChangeAvailability.unavailable(
        until: now.addingTimeInterval(60),
        duration: 60,
        exhaustedSkips: false
    )

    private static let freeServer = ServerInfo(logical: .mock, protocolSupport: .all)

    private static let capturedFile = URLWithSize(url: URL(filePath: "/tmp/capture.pcap"), size: 1024)

    private static let connected = ConnectionState.connected(
        .init(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: ["peer-id"], killSwitch: false),
        .init(currentPeer: .mock, connectionDate: .distantPast, protocolConnectionData: .proTUN(.init(transport: .udp)))
    )

    // MARK: - Private

    /// A store whose home screen starts with `destination` presented.
    ///
    /// The destination is built inside the store's dependency scope, because the upsell reads the
    /// server count from the repository to write its subtitle.
    private func makeStore(
        destination: @autoclosure @escaping () -> HomeFeature.Destination.State? = nil,
        withDependencies prepare: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<HomeFeature> {
        TestStore(initialState: Self.homeState(destination: destination())) {
            HomeFeature()
        } withDependencies: {
            $0.date = .constant(Self.now)
            $0.serverRepository = .notEmpty()
            prepare(&$0)
        }
    }

    private static func homeState(destination: HomeFeature.Destination.State?) -> HomeFeature.State {
        var state = HomeFeature.State()
        state.destination = destination
        return state
    }
}

/// The part of a connection command the home screen decides. `ConnectionCommand` carries completion
/// closures and cannot be compared, so tests record this instead.
private enum RecordedCommand: Equatable {
    case connect(ConnectionSpec, UserInitiatedVPNChange.VPNTrigger?)
    case disconnect(UserInitiatedVPNChange.VPNTrigger)
    case other

    init(_ command: ConnectionCommand) {
        switch command {
        case let .connect(spec, _, trigger):
            self = .connect(spec, trigger)
        case let .disconnect(trigger, _):
            self = .disconnect(trigger)
        case .retry, .reconnect, .applySettings, .clearConnectionData:
            self = .other
        }
    }
}

private extension DependencyValues {
    /// Records the commands the home screen sends instead of starting a connection.
    mutating func recordCommands(into commands: LockIsolated<[RecordedCommand]>) {
        connectionCommandClient.send = { command in
            commands.withValue { $0.append(RecordedCommand(command)) }
        }
    }
}
