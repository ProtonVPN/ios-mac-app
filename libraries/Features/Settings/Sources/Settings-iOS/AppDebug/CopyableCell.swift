//
//  Created on 19/05/2026 by Chris Janusiewicz.
//
//  Copyright (c) 2026 Proton AG
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

#if DEBUG
    import SettingsShared
    import SwiftUI
    import Theme

    struct CopyableCell: View {
        let title: String
        let value: String
        let isJSON: Bool

        @State private var copyCount = 0

        init(title: String, value: String) {
            self.title = title
            self.value = value
            self.isJSON = false
        }

        init(_ entry: NetworkConfigurationInfo.Entry) {
            self.title = entry.key
            switch entry.value {
            case let .string(value):
                self.value = value
                self.isJSON = false
            case let .json(value):
                self.value = value
                self.isJSON = true
            }
        }

        var body: some View {
            VStack(alignment: .leading) {
                Text(title).styled(.hint)
                Text(value)
                    .font(isJSON ? .system(.footnote, design: .monospaced) : .body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle()) // Make whole cell tappable
            .onTapGesture {
                UIPasteboard.general.string = value
                copyCount += 1
            }
            .sensoryFeedback(.selection, trigger: copyCount)
        }
    }
#endif
