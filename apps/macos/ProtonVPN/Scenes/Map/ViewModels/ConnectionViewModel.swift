//
//  ConnectionViewModel.swift
//  ProtonVPN - Created on 27.06.19.
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
import MapKit

struct ConnectionViewModel {
    
    enum State {
        case connected
        case proposed
    }
    
    enum Node {
        case home
        case server(CountryAnnotationViewModel)
    }
    
    let state: State
    let connection: (origin: Node, destination: CountryAnnotationViewModel)

    init(_ state: State, fromHomeTo node: CountryAnnotationViewModel) {
        self.state = state
        self.connection = (.home, node)
    }
    
    init(_ state: State, between origin: CountryAnnotationViewModel, and destination: CountryAnnotationViewModel) {
        self.state = state
        self.connection = (.server(origin), destination)
    }
}
