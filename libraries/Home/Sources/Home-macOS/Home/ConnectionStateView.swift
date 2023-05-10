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
    
    var body: some View {
        Text("Home view, click me")
            .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.background))
    }
}
