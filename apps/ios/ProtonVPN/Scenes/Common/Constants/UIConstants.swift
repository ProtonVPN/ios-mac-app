//
//  UIConstants.swift
//  ProtonVPN - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import GSMessages
import UIKit
import LegacyCommon

class UIConstants {
    
    // MARK: - Cell constants
    static let connectionStatusCellHeight: CGFloat = 48
    static let cellHeight: CGFloat = 52.5
    static let headerHeight: CGFloat = 56
    static let separatorHeight: CGFloat = 8
    static let countriesHeaderHeight: CGFloat = 40
    static let connectionBarHeight: CGFloat = 44
    
    // MARK: - Messages
    static let messageOptions: [GSMessageOption] = [
        .animations([.slide(.normal)]),
        .animationDuration(0.3),
        .autoHide(true),
        .autoHideDelay(4.0),
        .cornerRadius(0.0),
        .height(44.0),
        .hideOnTap(true),
        .margin(.zero),
        .padding(.init(top: 10, left: 15, bottom: 10, right: 15)),
        .position(.top),
        .textAlignment(.center),
        .textColor(.white),
        .textNumberOfLines(0),
    ]
    
    static let maxProfileNameLength = 25
}
