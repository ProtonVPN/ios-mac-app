//
//  Created on 24/03/2023.
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

import Foundation
import Dependencies
import Timer

// Allows us to not depend on Dependencies in VPNShared/network extension
public extension DependencyValues {
    var timerFactory: TimerFactory {
        get { self[TimerFactoryKey.self] }
        set { self[TimerFactoryKey.self] = newValue }
    }
}

public enum TimerFactoryKey: DependencyKey {
    public static let liveValue: TimerFactory = ForegroundTimerFactoryImplementation()
}
