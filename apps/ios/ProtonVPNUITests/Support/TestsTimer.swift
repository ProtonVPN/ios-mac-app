//
//  Created on 17/04/2024.
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

import Foundation

final class TestsTimer {
    private var startTime: Date? = nil
    private var endTime: Date? = nil
    
    func StartTimer() {
        startTime = Date()
    }
    
    func EndTimer() {
        endTime = Date()
    }
    
    func GetElapsedTime() -> String {
        let elapsedTime = endTime!.timeIntervalSince(startTime!)
        return String(format: "%.2f", elapsedTime)
    }
}
