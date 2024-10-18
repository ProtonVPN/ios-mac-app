//
//  Created on 14/10/2024.
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

/// The purpose of this struct is to store all the icons used in the shared views. The icons come from the core foundation
/// and importing them directly from the lib makes it impossible to use previews in this package. Thanks to this struct,
/// the dependency on foundationUI resources was removed.
public struct RecentsImages {
    public let wrench: Image
    public let threeDotsHorizontal: Image
    public let pinFilled: Image
    public let pinSlashFilled: Image
    public let trashCrossFilled: Image

    public init(
        wrenchImage: Image = Image(systemName: "wrench.adjustable"),
        threeDotsHorizontalImage: Image = Image(systemName: "ellipsis"),
        pinFilled: Image = Image(systemName: "pin.fill"),
        pinSlashFilled: Image = Image(systemName: "pin.slash.fill"),
        trashCrossFilled: Image = Image(systemName: "trash.fill")
    ) {
        self.wrench = wrenchImage
        self.threeDotsHorizontal = threeDotsHorizontalImage
        self.pinFilled = pinFilled
        self.pinSlashFilled = pinSlashFilled
        self.trashCrossFilled = trashCrossFilled
    }
}
