//
//  TroubleshootView.swift
//  ProtonVPN - Created on 15.12.2024.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import ComposableArchitecture
import Strings
import SwiftUI
import Theme

public struct TroubleshootView: View {
    @Bindable var store: StoreOf<TroubleshootFeature>
    let onDismiss: (() -> Void)?

    public init(store: StoreOf<TroubleshootFeature>, onDismiss: (() -> Void)? = nil) {
        self.store = store
        self.onDismiss = onDismiss
    }

    public var body: some View {
        #if os(iOS)
            NavigationView {
                contentWithToolbar
            }
        #elseif os(macOS)
            VStack(spacing: 0) {
                if onDismiss == nil {
                    macosToolbar
                }

                content
            }
            .frame(minWidth: Dimensions.width, minHeight: Dimensions.height)
        #endif
    }

    #if os(iOS)
        @ViewBuilder
        private var contentWithToolbar: some View {
            if #available(iOS 18.0, *) {
                content
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarContent }
                    .toolbarBackground(Color(uiColor: UIColor.secondaryBackgroundColor()), for: .navigationBar)
                    .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            } else {
                content
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarContent }
            }
        }

        @ToolbarContentBuilder
        private var toolbarContent: some ToolbarContent {
            ToolbarItem(placement: .principal) {
                Text(Localizable.troubleshootTitle)
                    .font(.system(size: 24))
                    .foregroundColor(Color(uiColor: UIColor.normalTextColor()))
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if let onDismiss {
                        onDismiss()
                    } else {
                        store.send(.closeButtonTapped)
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
            }
        }

    #elseif os(macOS)
        @ViewBuilder
        private var macosToolbar: some View {
            // Custom toolbar for macOS
            HStack {
                Text(Localizable.troubleshootTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(nsColor: NSColor.color(.text, .normal)))
                Spacer()
                Button(action: {
                    store.send(.closeButtonTapped)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(nsColor: NSColor.secondaryLabelColor))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, .themeSpacing16)
            .padding(.vertical, .themeSpacing12)
            .background(Color(nsColor: NSColor.windowBackgroundColor))

            Divider()
        }
    #endif

    private var content: some View {
        List {
            ForEach(store.scope(state: \.items, action: \.troubleshootItem)) { store in
                TroubleshootRowView(store: store)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.visible)
            }
        }
        .listStyle(.plain)
        .background(backgroundColor)
    }

    private var backgroundColor: Color {
        #if os(iOS)
            Color(uiColor: .backgroundColor())
        #elseif os(macOS)
            Color(.clear)
        #endif
    }

    #if os(macOS)
        private enum Dimensions {
            static let width: CGFloat = 480
            static let height: CGFloat = 500
        }
    #endif
}

#Preview {
    TroubleshootView(store: .init(initialState: .init(), reducer: {
        TroubleshootFeature()
    }))
}
