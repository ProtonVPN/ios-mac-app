//
//  Created on 23/04/2024.
//
//  Copyright (c) 2024 Proton AG
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

struct SettingsView: View {

    @Binding var path: NavigationPath
    @Environment(User.self) private var user: User

    enum Destination: String {
        case about
        case supportCenter
        case reportAnIssue
    }

    var body: some View {
        VStack(spacing: .themeSpacing24) {
            if let username = user.username {
                Text("Welcome \(username)")
                    .font(.title)
            }
            Text("Settings")
                .font(.title)

            NavigationLink(value: Destination.about) {
                SettingsCellView(title: "About")
            }
            NavigationLink(value: Destination.supportCenter) {
                SettingsCellView(title: "Support center")
            }
            NavigationLink(value: Destination.reportAnIssue) {
                SettingsCellView(title: "Report an issue")
            }
            Button {
                user.username = nil
                path = .init()
            } label: {
                SettingsCellView(title: "Log out")
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .about:
                    AboutView()
                case .supportCenter:
                    AboutView()
                case .reportAnIssue:
                    AboutView()
                }
            }
        }
        .frame(maxWidth: 800)
    }
}

struct SettingsCellView: View {
    
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.callout)
            Spacer()
        }
        .frame(height: 120)
    }
}
