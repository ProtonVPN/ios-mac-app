import Home
import VPNShared

// Todo: Snapshot testing for both macOS and iOS, for the Home view
// and all other child views defined in the Home package.

extension RecentConnection {
    static let pinnedActiveExactCHRegular: Self = .init(
        pinned: true,
        underMaintenance: false,
        connectionDate: .now,
        connection: .init(
            location: .exact(
                .paid,
                number: 42,
                subregion: nil,
                regionCode: "CH"
            ),
            features: []
        )
    )

    static let recentActiveExactSEStreaming: Self = .init(
        pinned: false,
        underMaintenance: false,
        connectionDate: .now,
        connection: .init(
            location: .exact(
                .paid,
                number: 420,
                subregion: nil,
                regionCode: "SE"
            ),
            features: [.streaming]
        )
    )

    static let recentRegionUSP2P: Self = .init(
        pinned: false,
        underMaintenance: false,
        connectionDate: .now,
        connection: .init(
            location: .region(code: "US"),
            features: [.p2p]
        )
    )
}
