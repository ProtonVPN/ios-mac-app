//
//  Created on 2025-05-02 by Pawel Jurczyk.
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

import SwiftUI
import Theme

struct ThemeToggleStyle: ToggleStyle {
    private let activeColor: Color = .init(.background, [.interactive])
    private let inactiveColor: Color = .init(.background, [.interactive, .weak])

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: .themeRadius16)
                .fill(configuration.isOn ? activeColor : inactiveColor)
                .overlay {
                    Circle()
                        .fill(.white)
                        .padding(1)
                        .offset(x: configuration.isOn ? 8 : -8)
                }
                .frame(width: 38, height: 22)
                .onTapGesture {
                    withAnimation {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}
