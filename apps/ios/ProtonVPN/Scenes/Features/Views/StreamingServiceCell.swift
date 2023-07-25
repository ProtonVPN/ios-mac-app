//
//  StreamingServiceCell.swift
//  ProtonVPN - Created on 20.04.21.
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
import LegacyCommon
import Alamofire
import AlamofireImage

class StreamingServiceCell: UICollectionViewCell {

    @IBOutlet private weak var serviceIV: UIImageView!
    @IBOutlet private weak var serviceLbl: UILabel!
    
    public var propertiesManager: PropertiesManagerProtocol!
    
    public var service: VpnStreamingOption? {
        didSet {
            serviceLbl.text = service?.name
            serviceIV.isHidden = true
            serviceLbl.isHidden = false
            
            guard propertiesManager.featureFlags.streamingServicesLogos,
                  let icon = service?.icon,
                  let baseUrl = propertiesManager.streamingResourcesUrl,
                  let url = URL(string: baseUrl + icon ) else {
                return
            }
            
            serviceIV.isHidden = false
            serviceLbl.isHidden = true
            serviceIV.af.cancelImageRequest()
            serviceIV.af.setImage(withURLRequest: URLRequest(url: url))
        }
    }
}
