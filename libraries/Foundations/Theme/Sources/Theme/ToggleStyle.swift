//
//  Created on 28/06/2023.
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

@available(tvOS 16.0, *)
extension ToggleStyle where Self == ChecklistToggleStyle {
    static var checklist: ChecklistToggleStyle { .init() }
}

@available(tvOS 16.0, *)
public struct ChecklistToggleStyle: ToggleStyle {
    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        return HStack {
            configuration.label
            Spacer()
            Accessory(style: .checkmark(isActive: configuration.isOn))
        }
        .background(Color(.background, .normal))
        .onTapGesture { configuration.isOn.toggle() }
    }
}

@available(tvOS 16.0, *)
struct ToggleStyle_Previews: PreviewProvider {

    struct WrapperView: View {
        @State var firstToggleValue: Bool = true
        @State var secondToggleValue: Bool = false

        var body: some View {
            List {
                Toggle("Stuff", isOn: $firstToggleValue)
                Toggle("Other Stuff", isOn: $secondToggleValue)
            }
            .toggleStyle(ChecklistToggleStyle())
        }
    }

    static var previews: some View {
        WrapperView()
    }
}
