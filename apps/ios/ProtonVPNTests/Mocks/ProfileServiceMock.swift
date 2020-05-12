//
//  ProfileServiceMock.swift
//  ProtonVPN - Created on 19/07/2019.
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

class ProfileServiceMock: ProfileService {
    
    var dataSet: SelectionDataSet?
    
    func makeProfilesViewController() -> ProfilesViewController {
        return ProfilesViewController()
    }
    
    func makeCreateProfileViewController(for profile: Profile?) -> CreateProfileViewController? {
        return nil
    }
    
    func makeSelectionViewController(dataSet: SelectionDataSet, dataSelected: @escaping (Any) -> Void) -> SelectionViewController {
        self.dataSet = dataSet
        return SelectionViewController()
    }
    
}
