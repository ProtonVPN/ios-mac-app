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

import Strings
import SwiftUI

public struct TroubleshootView: View {
    @ObservedObject var viewModel: TroubleshootViewModel

    public init(viewModel: TroubleshootViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        #if os(iOS)
            NavigationView {
                contentWithToolbar
            }
        #elseif os(macOS)
            content
                .frame(width: 480, height: 503)
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
                    viewModel.cancel()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
            }
        }
    #endif

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.items.enumerated()), id: \.offset) { index, item in
                    TroubleshootRowView(item: item)
                    if index < viewModel.items.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .background(backgroundColor)
    }

    private var backgroundColor: Color {
        #if os(iOS)
            Color(uiColor: .backgroundColor())
        #elseif os(macOS)
            Color(.clear)
        #endif
    }
}
