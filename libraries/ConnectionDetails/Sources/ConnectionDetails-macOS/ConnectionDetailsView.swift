//
//  Created on 2023-05-31.
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
import Theme_macOS

public struct ConnectionDetailsView: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 0) {
            Divider()
                .ignoresSafeArea()
                .frame(minWidth: 1, maxWidth: 1, maxHeight: .infinity) // the drawn size of the draggable line
                .background(Color(.border))
                .padding([.horizontal], 6) // the width of the draggable space, it extends over the drawn view
                .background(Color(.background))
                .onHover(perform: { hovering in
                    if (hovering) {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                })
                .gesture(
                    DragGesture().onChanged({ value in
                        print(value) // not implemented, just print it out
                    })
                )

            Text("Connection details view")
                .frame(minWidth: 260, maxHeight: .infinity)
                .background(Color(.background))
        }
    }
}

// MARK: - Previews

struct ConnectionDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionDetailsView()
    }
}
