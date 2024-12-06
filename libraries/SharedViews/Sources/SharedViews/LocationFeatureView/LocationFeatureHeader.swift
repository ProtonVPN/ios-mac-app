//
//  Created on 05/12/2024.
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

public struct LocationFeatureHeaderModel: Equatable {
    let title: String
    let showConnectedPin: Bool

    public init(title: String, showConnectedPin: Bool) {
        self.title = title
        self.showConnectedPin = showConnectedPin
    }
}

struct LocationFeatureHeader: View {
    
    let model: LocationFeatureHeaderModel

    init(model: LocationFeatureHeaderModel) {
        self.model = model
    }

    var body: some View {
        HStack {
            text
            if model.showConnectedPin {
                connectedPin
            }
        }
    }

    private var text: some View {
        Text(model.title)
            .styled()
#if canImport(Cocoa)
            .themeFont(.body(emphasised: true))
#elseif canImport(UIKit)
            .themeFont(.body1(.semibold))
#endif
    }

    private var connectedPin: some View {
        ZStack {
            Circle()
                .fill(Color(.icon, .vpnGreen).opacity(0.2))
                .frame(.square(20))
            Circle()
                .fill(Color(.icon, .vpnGreen))
                .frame(.square(8))
        }
    }
}
