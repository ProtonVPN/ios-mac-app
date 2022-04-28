//
//  TimerFactoryMock.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public class TimerFactoryMock: TimerFactoryProtocol {
    
    private let timer = Timer(timeInterval: TimeInterval.infinity, repeats: false, block: { (_) in })
    private var closure: ((Timer) -> Void)!
    
    public init() {}
    
    public func timer(timeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        closure = block
        return timer
    }
    
    public func fireTimer() {
        closure(timer)
    }
}
