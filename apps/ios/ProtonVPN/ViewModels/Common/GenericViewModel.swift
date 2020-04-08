//
//  GenericViewModel.swift
//  ProtonVPN - Created on 07/04/2020.
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

import Foundation

protocol GenericViewModel {
    func viewDidLoad()
    func viewWillAppear( _ animated: Bool)
    func viewDidAppear( _ animated: Bool)
    func viewWillDisappear( _ animated: Bool)
    func viewDidDisappear( _ animated: Bool)
}

// MARK: - Optionals

extension GenericViewModel {
    func viewDidLoad() {}
    func viewWillAppear( _ animated: Bool){}
    func viewDidAppear( _ animated: Bool){}
    func viewWillDisappear( _ animated: Bool){}
    func viewDidDisappear( _ animated: Bool){}
}
