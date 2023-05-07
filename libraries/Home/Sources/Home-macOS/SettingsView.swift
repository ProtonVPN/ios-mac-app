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

public struct SettingsView: View {

    @State private var currentSubview = AnyView(EmptyView())
    @State private var showingSubview = false

    public init() { }

    private func showSubview(view: AnyView) {
        withAnimation(.easeOut(duration: 0.3)) {
            currentSubview = view
            showingSubview = true
        }
    }

    public var body: some View {
        StackNavigationView(currentSubview: $currentSubview,
                            showingSubview: $showingSubview) {
            Button {
                showSubview(view: AnyView(Text("Subview!")))
            } label: {
                Text("Show subview")
            }
        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.background))
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
