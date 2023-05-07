//
//  Created on 07/05/2023.
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
import Theme

struct ConnectionStateView: View {

    @Binding var connectionDetailsVisible: Bool

    public init(connectionDetailsVisible: Binding<Bool>) {
        _connectionDetailsVisible = connectionDetailsVisible
    }

    @State var size: CGSize = .zero

    var body: some View {
        // The app window better manages it's size when this view is laid out with ZStack
        ZStack {
            HStack(spacing: 0) {
                Text("Home view, click me")
                    .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.background))
                // Blank space behind the connection details, needed because of the ZStack
                if connectionDetailsVisible {
                    Spacer()
                        .frame(width: 260)
                }
            }
            if connectionDetailsVisible {
                HStack(spacing: 0) {
                    Spacer()
                    Divider()
                        .frame(minWidth: 1, maxWidth: 1, maxHeight: .infinity)
                        .background(Color(.border))
                    Text("Connection details view")
                        .frame(minWidth: 260, maxWidth: 260, maxHeight: .infinity)
                        .background(Color(.background))
                }
            }
        }
    }
}
