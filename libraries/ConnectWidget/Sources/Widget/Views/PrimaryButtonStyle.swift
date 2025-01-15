//
//  Created on 15/01/2025.
//
//  Copyright (c) 2025 Proton AG
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

import Foundation
import SwiftUI

import Theme

public struct PrimaryButtonStyle: ButtonStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(Color(.text, .primary))
            .frame(maxWidth: .infinity, minHeight: .themeSpacing24)
            .bold()
            .padding(.vertical, .themeSpacing8)
            .background(Color(.background, [.interactive]))
            .clipRectangle(cornerRadius: .radius12)
    }
}

struct PrimaryButtonStyle_Previews: PreviewProvider {
    static var previews: some View {
        Button {

        } label: {
            Text("Preview button")
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}
