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

    private enum AccessibilityIdentifiers {
        static let connectionFlagInfo: String = "connection_flag_info_view"
    }

    let intent: ConnectionSpec
    let isPinned: Bool
    let underMaintenance: Bool
    let isConnected: Bool

    let textHeaderString: String
    let subheaderModel: LocationFeatureSubheaderModel
    let resolvedLocation: ConnectionSpec.Location

    let attachedLeadingView: (() -> AnyView)?

    let detailAction: ((Action) -> Void)?
    let images: RecentsImages

    @ScaledMetric
    private var maintenanceIconSize: CGFloat = 24

    @State private var showDetail = false

    public init(
        intent: ConnectionSpec,
        underMaintenance: Bool = false,
        isPinned: Bool,
        server: Server? = nil,
        withServerNumber: Bool = false,
        isConnected: Bool,
        images: RecentsImages = .init(),
        attachedLeadingView: (() -> AnyView)? = nil,
        detailAction: ((Action) -> Void)? = nil
    ) {
        self.intent = intent
        self.underMaintenance = underMaintenance
        self.isConnected = isConnected
        self.attachedLeadingView = attachedLeadingView
        self.detailAction = detailAction
        self.isPinned = isPinned
        self.images = images

        let infoBuilder = ConnectionInfoBuilder(
            intent: intent,
            server: server,
            withServerNumber: withServerNumber
        )
        self.textHeaderString = infoBuilder.textHeader
        self.subheaderModel = infoBuilder.subheader
        self.resolvedLocation = infoBuilder.resolvedLocation
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 0) {
            LocationFeatureView(
                model: .init(
                    flag: resolvedLocation.flagComposition,
                    header: .init(title: textHeaderString, showConnectedPin: isConnected),
                    subheader: subheaderModel
                ),
                attachedLeadingView: attachedLeadingView
            )

            Spacer()

            if underMaintenance {
                images
                    .wrench
                    .resizable()
                    .frame(.square(maintenanceIconSize))
                    .foregroundColor(.init(.icon, .weak))
                    .padding(.horizontal, .themeSpacing12)
            }

            if let detailAction {
                Button(action: {
                    showDetail = true
                }, label: {
                    images
                        .threeDotsHorizontal
                        .foregroundStyle(Color(.icon))
                        .frame(.square(.themeSpacing64))
                })
                .sheet(isPresented: self.$showDetail) {
                    RecentConnectionActionsView(intent: intent, isPinned: isPinned, images: images) { action in
                        showDetail = false
                        detailAction(action)
                    }
                    .presentationDetents([.fraction(1 / 3)])
                    .presentationDragIndicator(.visible)
                }.background(Color(.background)) // Sets background of the three dots button
            }
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(AccessibilityIdentifiers.connectionFlagInfo)
    }

    var connectedPin: some View {
        ZStack {
            Circle()
                .fill(Color(.icon, .vpnGreen).opacity(0.2))
                .frame(.square(20))
            Circle()
                .fill(Color(.icon, .vpnGreen))
                .frame(.square(8))
        }
    }

    var textHeader: some View {
        Text(textHeaderString)
            .styled()
        #if canImport(Cocoa)
            .themeFont(.body(emphasised: true))
        #elseif canImport(UIKit)
            .themeFont(.body1(.semibold))
        #endif
    }
}

#if DEBUG
    struct ConnectionFlagView_Previews: PreviewProvider {
        static let cellHeight = 40.0
        static let cellWidth = 300.0
        static let spacing = 20.0

        static func sideBySide(intent: ConnectionSpec, actual: VPNConnectionActual) -> some View {
            HStack(alignment: .top, spacing: spacing) {
                ConnectionFlagInfoView(intent: intent,
                                       underMaintenance: false,
                                       isPinned: true,
                                       isConnected: .random()) { _ in
                    // NO-OP
                }
                .frame(width: cellWidth)

                Divider()

                ConnectionFlagInfoView(intent: intent,
                                       isPinned: true,
                                       server: actual.server,
                                       isConnected: .random())
                    .frame(width: cellWidth)
            }
            .frame(height: cellHeight)
        }

        static var previews: some View {
            VStack {
                ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                              features: []),
                                       isPinned: true,
                                       server: VPNConnectionActual.mock().server,
                                       isConnected: .random()) { _ in
                    // NO-OP
                }
                ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                              features: []),
                                       isPinned: false,
                                       server: VPNConnectionActual.mock().server,
                                       isConnected: .random()) { _ in
                    // NO-OP
                }
                ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                              features: [.p2p, .tor]),
                                       isPinned: true,
                                       server: VPNConnectionActual.mock(feature: ServerFeature(arrayLiteral: .p2p, .tor)).server,
                                       isConnected: .random()) { _ in
                    // NO-OP
                }
                ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                              features: [.p2p, .tor]),
                                       isPinned: true,
                                       server: VPNConnectionActual.mock(feature: ServerFeature(arrayLiteral: .p2p, .tor)).server,
                                       isConnected: .random()) { _ in
                    // NO-OP
                }
                ConnectionFlagInfoView(intent: ConnectionSpec(location: .fastest,
                                                              features: []),
                                       isPinned: true,
                                       server: VPNConnectionActual.mock().server,
                                       isConnected: .random()) { _ in
                    // NO-OP
                }
                ConnectionFlagInfoView(intent: ConnectionSpec(location: .fastest,
                                                              features: [.p2p, .tor]),
                                       isPinned: true,
                                       server: VPNConnectionActual.mock(feature: ServerFeature(arrayLiteral: .p2p, .tor)).server,
                                       isConnected: .random()) { _ in
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
                    intent: ConnectionSpec(location: .exact(.free, logicalID: nil, number: 1, subregion: nil, regionCode: "US"), features: []),
                    actual: .mock(serverName: "FREE #1")
                )
                sideBySide(
                    intent: ConnectionSpec(location: .exact(.paid, logicalID: nil, number: nil, subregion: "Dallas", regionCode: "US"), features: [.p2p, .tor]),
                    actual: .mock(feature: [.p2p, .tor])
                )
                sideBySide(
                    intent: ConnectionSpec(location: .exact(.paid, logicalID: nil, number: 1, subregion: "AR", regionCode: "US"), features: []),
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
