//
//  NetshieldServiceMock.swift
//  ProtonVPN - Created on 2020-09-14.
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
import vpncore

class NetshieldServiceMock: NetshieldService {
    
    public var viewModel: NetshieldSelectionViewModel
    
    public init(viewModel: NetshieldSelectionViewModel) {
        self.viewModel = viewModel
    }
    
    public var callbackMakeNetshieldSelectionViewController: ((NetShieldType, @escaping NetshieldSelectionViewModel.ApproveCallback, @escaping NetshieldSelectionViewModel.TypeChangeCallback) -> NetshieldSelectionViewController)?
    
    public func makeNetshieldSelectionViewController(selectedType: NetShieldType, approve: @escaping NetshieldSelectionViewModel.ApproveCallback, onChange: @escaping NetshieldSelectionViewModel.TypeChangeCallback) -> NetshieldSelectionViewController {
        return callbackMakeNetshieldSelectionViewController?(selectedType, approve, onChange) ?? NetshieldSelectionViewController(viewModel: viewModel)
    }
}

