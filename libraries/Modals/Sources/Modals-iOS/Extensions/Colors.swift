//
//  Created on 2/8/22.
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

import UIKit
import Theme

var colors = Colors()

public protocol ModalsColors {
    var background: UIColor { get }
    var secondaryBackground: UIColor { get }
    var buttonTitle: UIColor { get }
    var text: UIColor { get }
    var textAccent: UIColor { get }
    var brand: UIColor { get }
    var weakText: UIColor { get }
    var weakInteraction: UIColor { get }
    var success: UIColor { get }
}

public struct Colors {
    public let background: UIColor
    public let secondaryBackground: UIColor
    public let buttonTitle: UIColor
    public let text: UIColor
    public let textAccent: UIColor
    public let brand: UIColor
    public let weakText: UIColor
    public let weakInteraction: UIColor
    public let success: UIColor

    public init() {
        self.background = .color(.background)
        self.secondaryBackground = .color(.background, .weak)
        self.buttonTitle = .color(.text, .primary)
        self.text = .color(.text)
        self.textAccent = Asset.mobileTextAccent.color
        self.brand = Asset.mobileBrandNorm.color
        self.weakText = .color(.text, .weak)
        self.weakInteraction = .color(.background, [.interactive, .weak])
        self.success = .color(.background, .success)
    }
}

extension Colors: ModalsColors { }
