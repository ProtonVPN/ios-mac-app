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
import ComposableArchitecture

struct CodeExpiredView: View {

    var store: StoreOf<CodeExpiredFeature>

    @FocusState var focusState: Bool

    var body: some View {
        VStack(spacing: .themeSpacing64) {
            Text("Your verification code expired", comment: "Header text, appears when the verification code expires and user can no longer use it to authenticate")
                .font(.title)
                .fontWeight(.bold)
            Button {
                store.send(.generateNewCode)
            } label: {
                Text("Generate new code", comment: "Button title, when user clicks on it, a new verification code is generated and user can try to authenticate again")
            }
            .focused($focusState, equals: true)
            .buttonStyle(TVButtonStyle())
        }
        .background(Image(.backgroundStage))
    }
}
