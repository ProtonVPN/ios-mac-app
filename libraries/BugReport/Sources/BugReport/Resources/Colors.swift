//
//  Created on 2022-01-04.
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

import Foundation
import SwiftUI

@available(iOS 14.0, *)
public struct Colors {
    
    public init() { }
        
    public var brand: Color = Color("brand", bundle: Bundle.module)
    public var brandLight20: Color = Color("brand-lighten20", bundle: Bundle.module)
    public var brandLight40: Color = Color("brand-lighten40", bundle: Bundle.module)
    public var brandDark40: Color = Color("brand-darken40", bundle: Bundle.module)
    
    public var textPrimary: Color = Color.white
    public var textSecondary: Color = Color("text-weak", bundle: Bundle.module)
    
    public var background: Color = Color("background-norm", bundle: Bundle.module)
    public var backgroundSecondary: Color = Color("background-secondary", bundle: Bundle.module)
    public var separator: Color = Color("separator", bundle: Bundle.module)
    
    public var qfIcon: Color = Color("notification-warning", bundle: Bundle.module)
    
}

@available(iOS 14.0, *)
struct ColorsEnvironmentKey: EnvironmentKey {
    static var defaultValue = Colors()
}

@available(iOS 14.0, *)
extension EnvironmentValues {
    var colors: Colors {
        get { self[ColorsEnvironmentKey.self] }
        set { self[ColorsEnvironmentKey.self] = newValue }
    }
}
