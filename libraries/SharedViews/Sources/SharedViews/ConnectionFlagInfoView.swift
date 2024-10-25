//
//  Created on 2023-06-30.
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

import SwiftUI
import Domain
import Strings
import Theme
import VPNAppCore

public struct ConnectionFlagInfoView: View {

    public enum Action {
        case pin
        case unpin
        case remove
    }

    let intent: ConnectionSpec
    let isPinned: Bool
    let underMaintenance: Bool
    let connectionInfoBuilder: ConnectionInfoBuilder
    let withDivider: Bool

    @State var showDetail = false

    let detailAction: ((Action) -> Void)?
    let images: RecentsImages

    @ScaledMetric
    private var maintenanceIconSize: CGFloat = 24

    public init(
        intent: ConnectionSpec,
        underMaintenance: Bool = false,
        isPinned: Bool,
        vpnConnectionActual: VPNConnectionActual? = nil,
        withDivider: Bool,
        images: RecentsImages = .init(),
        detailAction: ((Action) -> Void)? = nil
    ) {
        self.intent = intent
        self.underMaintenance = underMaintenance
        self.connectionInfoBuilder = .init(intent: intent, vpnConnectionActual: vpnConnectionActual)
        self.withDivider = withDivider
        self.detailAction = detailAction
        self.isPinned = isPinned
        self.images = images
    }

    public var body: some View {
        HStack(spacing: 0) {
            flag
            Spacer()
                .frame(width: 12)
            ZStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(connectionInfoBuilder.textHeader)
                            .styled()
#if canImport(Cocoa)
                            .themeFont(.body(emphasised: true))
#elseif canImport(UIKit)
                            .themeFont(.body1(.semibold))
#endif

                        if connectionInfoBuilder.hasTextFeatures {
                            connectionInfoBuilder
                                .textFeatures
                                .lineLimit(2)
                                .foregroundColor(.init(.border))
                        }
                    }

                    Spacer()

                    if underMaintenance {
                        images
                            .wrench
                            .resizable()
                            .frame(.square(maintenanceIconSize))
                            .foregroundColor(.init(.icon, .weak))
                            .padding(.horizontal, .themeSpacing12)
                    }

                    if #available(iOS 16.0, macOS 13.0, *), let detailAction {
                        Button(action: {
                            showDetail = true
                        }, label: {
                            images
                                .threeDotsHorizontal
                                .foregroundStyle(Color(.icon))
                        })
                        .popover(isPresented: self.$showDetail, attachmentAnchor: .point(.topLeading)) {
                            RecentConnectionActionsView(intent: intent, isPinned: isPinned, images: images) { action in
                                showDetail = false
                                detailAction(action)
                            }
                            .presentationDetents([.fraction(1 / 3)])
                            .presentationDragIndicator(.visible)
                        }
                    }
                }
                if withDivider {
                    VStack() {
                        Spacer()
                        Divider()
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
        .frame(height: withDivider ? 64 : 42)
    }

    private var flag: some View {
        VStack(spacing: 0) {
            if withDivider {
                Spacer()
                    .frame(width: 20, height: 12)
            }
            FlagView(location: intent.location, flagSize: .defaultSize)
            if connectionInfoBuilder.hasTextFeatures {
                Spacer()
            }
            if withDivider {
                Spacer()
                    .frame(height: 12)
            }
        }
    }
}

#if DEBUG
struct ConnectionFlagView_Previews: PreviewProvider {

    static let cellHeight = 40.0
    static let cellWidth = 300.0
    static let spacing = 20.0

    static func sideBySide(intent: ConnectionSpec, actual: VPNConnectionActual) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            ConnectionFlagInfoView(intent: intent, underMaintenance: false, isPinned: true, withDivider: true) { _ in
                // NO-OP
            }
            .frame(width: cellWidth)

            Divider()

            ConnectionFlagInfoView(intent: intent, underMaintenance: false, isPinned: true, vpnConnectionActual: actual, withDivider: false)
                .frame(width: cellWidth)
        }
        .frame(height: cellHeight)
    }

    static var previews: some View {
        VStack {
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                          features: []),
                                   underMaintenance: false, 
                                   isPinned: true,
                                   vpnConnectionActual: .mock(),
                                   withDivider: true) { _ in
                // NO-OP
            }
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                          features: []),
                                   underMaintenance: false, 
                                   isPinned: false,
                                   vpnConnectionActual: .mock(),
                                   withDivider: false) { _ in
                // NO-OP
            }
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                          features: [.p2p, .tor]),
                                   underMaintenance: false,
                                   isPinned: true,
                                   vpnConnectionActual: .mock(feature: ServerFeature(arrayLiteral: .p2p, .tor)),
                                   withDivider: true) { _ in
                // NO-OP
            }
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                          features: [.p2p, .tor]),
                                   underMaintenance: false,
                                   isPinned: true,
                                   vpnConnectionActual: .mock(feature: ServerFeature(arrayLiteral: .p2p, .tor)),
                                   withDivider: false) { _ in
                // NO-OP
            }
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .fastest,
                                                          features: []),
                                   underMaintenance: false,
                                   isPinned: true,
                                   vpnConnectionActual: .mock(),
                                   withDivider: true) { _ in
                // NO-OP
            }
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .fastest,
                                                          features: [.p2p, .tor]),
                                   underMaintenance: false,
                                   isPinned: true,
                                   vpnConnectionActual: .mock(feature: ServerFeature(arrayLiteral: .p2p, .tor)),
                                   withDivider: false) { _ in
                // NO-OP
            }
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .preferredColorScheme(.dark)
        .previewDisplayName("Single")

        VStack(alignment: .leading, spacing: spacing) {
            HStack(alignment: .bottom, spacing: spacing) {
                Text("Not connected").frame(width: cellWidth)
                Divider()
                Text("Connected").frame(width: cellWidth)
            }.frame(height: cellHeight)
            Divider().frame(width: (cellWidth + spacing) * 2)

            sideBySide(
                intent: ConnectionSpec(location: .fastest, features: []),
                actual: .mock()
            )
            sideBySide(
                intent: ConnectionSpec(location: .region(code: "US"), features: []),
                actual: .mock()
            )
            sideBySide(
                intent: ConnectionSpec(location: .region(code: "US"), features: [.tor]),
                actual: .mock(feature: .tor)
            )
            sideBySide(
                intent: ConnectionSpec(location: .exact(.free, number: 1, subregion: nil, regionCode: "US"), features: []),
                actual: .mock(serverName: "FREE #1")
            )
            sideBySide(
                intent: ConnectionSpec(location: .exact(.paid, number: nil, subregion: "Dallas", regionCode: "US"), features: [.p2p, .tor]),
                actual: .mock(feature: [.p2p, .tor])
            )
            sideBySide(
                intent: ConnectionSpec(location: .exact(.paid, number: 1, subregion: "AR", regionCode: "US"), features: []),
                actual: .mock()
            )
            sideBySide(
                intent: ConnectionSpec(location: .secureCore(.fastest), features: []),
                actual: .mock(country: "SE")
            )
            sideBySide(
                intent: ConnectionSpec(location: .secureCore(.hop(to: "JP", via: "CH")), features: []),
                actual: .mock()
            )
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .preferredColorScheme(.dark)
        .previewDisplayName("sideBySide")
    }
}
#endif
