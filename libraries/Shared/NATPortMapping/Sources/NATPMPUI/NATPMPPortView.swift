//
//  Created on 24/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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

import ComposableArchitecture
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

public struct NATPMPPortView: View {
    @Perception.Bindable var store: StoreOf<NATPMPFeature>

    public init() {
        let store = Store(initialState: .loading(lastExternalPortNumber: nil, lastUsedUpdateDate: nil)) {
            NATPMPFeature()
        }
        self.init(store: store)
    }

    public init(store: StoreOf<NATPMPFeature>) {
        self.store = store
    }

    public var body: some View {
        HStack {
            switch store.state {
            case .loading:
                LoadingPortView()
            case let .loaded(externalPortNumber, updateDate):
                ActivePortView(
                    portNumber: externalPortNumber,
                    updateDate: updateDate
                )
            case .error:
                PortErrorView()
            }
        }
        .onAppear {
            store.send(.startPortMappingObservation)
        }
        .onDisappear {
            store.send(.stopPortMappingObservation)
        }
    }
}

// MARK: - Active Port View

struct ActivePortView: View {
    let portNumber: UInt16
    let updateDate: Date

    @State private var hovered = false
    @State private var showCopiedTooltip = false

    var body: some View {
        Button(action: {
            copyPortNumber(portNumber) {
                // Show copied tooltip
                showCopiedTooltip = true

                // Hide tooltip after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCopiedTooltip = false
                    }
                }
            }
        }) {
            VStack(alignment: .leading, spacing: .themeSpacing4) {
                // Header with status indicator
                Text(Localizable.pfActivePortNumber)
                    .foregroundColor(Color(.text, .weak))
                    .themeFont(.callout(emphasised: true))

                // Port number with copy button
                HStack(alignment: .center, spacing: .themeSpacing4) {
                    // Green status indicator
                    Asset.pfIndicator.swiftUIImage
                        .resizable()
                        .frame(.square(.themeSpacing16))

                    Text(String(portNumber))
                        .foregroundColor(Color(.text))
                        .font(.title2(emphasised: false))
                        .offset(y: 1)
                        .popover(isPresented: $showCopiedTooltip, arrowEdge: .top) {
                            Text(Localizable.pfCopied)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                        }

                    IconProvider.squares
                        .resizable()
                        .frame(.square(.themeSpacing16))

                    Spacer()
                }

                HStack(spacing: .themeSpacing4) {
                    Asset.pfIndicator.swiftUIImage
                        .resizable()
                        .opacity(0)
                        .frame(.square(.themeSpacing16))

                    TimelineView(.periodic(from: updateDate, by: 1)) { context in
                        Text(formatUpdateTime(updateDate, currentTime: context.date))
                            .foregroundColor(Color(.text, .weak))
                            .themeFont(.callout(emphasised: false))
                    }

                    Spacer()
                }
            }
            .padding(.themeSpacing16)
            .background(hovered ? Color(.background, .strong) : Color(.background, .weak))
            .cornerRadius(.themeRadius8)
            .overlay {
                CursorAreaViewRepresentable()
            }
        }
        .onHover { isHovered in
            guard hovered != isHovered else { return }
            hovered = isHovered
        }
        .buttonStyle(.plain)
        .help(Localizable.pfCopyPortNumber)
    }

    // MARK: - State

    private static let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter
    }()

    private func formatUpdateTime(_ date: Date, currentTime: Date) -> String {
        let timeAgo = Self.relativeDateTimeFormatter.localizedString(for: date, relativeTo: currentTime)
        return Localizable.pfUpdated(timeAgo)
    }
}

// MARK: - Loading Port View

struct LoadingPortView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                Text(Localizable.pfActivePortNumber)
                    .foregroundColor(Color(.text, .weak))
                    .themeFont(.callout(emphasised: true))

                HStack(spacing: .themeSpacing8) {
                    ProgressView()
                        .scaleEffect(0.8)

                    Text(Localizable.pfLoading)
                        .foregroundColor(Color(.text))
                        .font(.title2(emphasised: false))
                }
            }
            Spacer()
        }
        .padding(.themeSpacing16)
        .background(Color(.background, .weak))
        .cornerRadius(.themeRadius8)
    }
}

// MARK: - Port Error View

struct PortErrorView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                Text(Localizable.pfActivePortNumber)
                    .foregroundColor(Color(.text, .weak))
                    .themeFont(.callout(emphasised: true))

                HStack(spacing: .themeSpacing8) {
                    IconProvider.circleSlash
                        .resizable()
                        .frame(.square(.themeSpacing16))

                    Text(Localizable.pfError)
                        .foregroundColor(Color(.text))
                        .font(.title2(emphasised: false))
                }
            }
            Spacer()
        }
        .padding(.themeSpacing16)
        .background(Color(.background, .weak))
        .cornerRadius(.themeRadius8)
    }
}

// MARK: - Status Port View

public class MappedPort: ObservableObject {
    @Published public var portNumber: UInt16?

    public init() {}

    init(portNumber: UInt16?) {
        self.portNumber = portNumber
    }
}

public struct StatusPortView: View {
    @ObservedObject public var portModel: MappedPort = .init()
    @State private var hovered = false

    public init(portModel: MappedPort) {
        self.portModel = portModel
    }

    public var body: some View {
        if let portNumber = portModel.portNumber {
            HStack {
                Button(action: {
                    copyPortNumber(portNumber)
                }) {
                    HStack(spacing: .themeSpacing4) {
                        Text(Localizable.pfActivePortStatus)
                            .foregroundColor(Color(.text))
                            .themeFont(.body(emphasised: true))

                        Asset.pfIndicator.swiftUIImage
                            .resizable()
                            .frame(.square(.themeSpacing12))

                        Text(String(portNumber))
                            .foregroundColor(Color(.text))
                            .font(.title3(emphasised: false))

                        IconProvider.squares
                            .resizable()
                            .frame(.square(.themeSpacing12))
                    }
                    .overlay {
                        CursorAreaViewRepresentable()
                    }
                    .padding(.themeSpacing2)
                    .background(hovered ? .white.opacity(0.15) : .clear)
                    .cornerRadius(.themeRadius4)
                }
                .onHover { isHovered in
                    hovered = isHovered
                }
                .buttonStyle(.plain)
                .help(Localizable.pfCopyPortNumber)

                Spacer()
            }
        } else {
            EmptyView()
        }
    }
}

private func copyPortNumber(_ portNumber: UInt16, onCopied: (() -> Void)? = nil) {
    let portString = String(portNumber)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(portString, forType: .string)

    // Call the callback if provided
    onCopied?()
}

// MARK: - Preview

#if DEBUG
    #Preview {
        VStack(spacing: 16) {
            // Active state
            ActivePortView(
                portNumber: 36528,
                updateDate: Date().addingTimeInterval(-35 * 60) // 35 minutes ago
            )

            // Loading state
            LoadingPortView()

            // Error state
            PortErrorView()

            // Status view
            StatusPortView(portModel: MappedPort(portNumber: 36528))
        }
        .padding()
        .background(Color(.background))
    }
#endif

private class CursorAreaView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    override func updateTrackingAreas() {
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseEntered(with event: NSEvent) {
        event.window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(visibleRect, cursor: NSCursor.pointingHand)
    }
}

private struct CursorAreaViewRepresentable: NSViewRepresentable {
    func updateNSView(_: CursorAreaView, context _: Context) {}

    func makeNSView(context _: Context) -> CursorAreaView {
        let view = CursorAreaView()
        return view
    }
}
