//
//  SecureCoreEntryAnnotation.swift
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

import UIKit
import CoreLocation

class SecureCoreEntryAnnotation: AnnotationView {

    let countryModel: SecureCoreEntryCountryModel
    
    override var coordinate: CLLocationCoordinate2D {
        return countryModel.coordinate
    }

    var maxHeight: CGFloat {
        return 30
    }
    
    var width: CGFloat {
        return 30
    }
    
    override var frame: CGRect {
        didSet {
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    init(frame: CGRect, scEntryCountryModel: SecureCoreEntryCountryModel) {
        self.countryModel = scEntryCountryModel
        
        super.init(frame: frame)
        
        layer.cornerRadius = maxHeight * 0.5
        backgroundColor = .brandColor()
    }
}
