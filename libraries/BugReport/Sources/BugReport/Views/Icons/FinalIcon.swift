//
//  Created on 2022-01-07.
//
//  Copyright (c) 2022 Proton AG
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

/// Image for usage in final modal. Can present success or failure state.
@available(iOS 14.0, *)
struct FinalIcon: View {
    enum State {
        case success
        case failure
    }
    
    let state: State
    
    var body: some View {
        ZStack(alignment: .center) {
            Image(Asset.icClipboard.name, bundle: .module)
            icon.frame(width: 138, height: 160, alignment: .bottomLeading)
        }
    }
    
    var icon: Image {
        switch state {
        case .success:
            return Image(Asset.icSuccess.name, bundle: .module)
        case .failure:
            return Image(Asset.icFailure.name, bundle: .module)
        }
    }
}

// MARK: - Preview

@available(iOS 14.0, *)
struct FinalIcon_Previews: PreviewProvider {
    static var previews: some View {
        FinalIcon(state: .success)
        FinalIcon(state: .failure)
    }
}
