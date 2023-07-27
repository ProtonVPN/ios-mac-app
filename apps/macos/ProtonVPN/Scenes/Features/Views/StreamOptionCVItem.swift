//
//  StreamOptionCVItem.swift
//  ProtonVPN - Created on 22.04.21.
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

import Cocoa
import LegacyCommon
import Ergonomics

class StreamOptionCVItem: NSCollectionViewItem {

    @IBOutlet private weak var serviceIV: NSImageView!
    @IBOutlet private weak var serviceLbl: NSTextField!
        
    public var viewModel: StreamOptionCVItemViewModelProtocol? {
        didSet {
            guard let viewModel = self.viewModel else { return }
            
            serviceLbl.stringValue = viewModel.serviceName
            serviceIV.isHidden = true
            serviceLbl.isHidden = false
            view.wantsLayer = true
            DarkAppearance {
                view.layer?.backgroundColor = .cgColor(.background)
            }
            
            guard let url = viewModel.url else { return }
            
            serviceIV.sd_cancelCurrentImageLoad()
            serviceIV.sd_setImage(with: url) { [weak self] (_, _, _, _) in
                self?.serviceIV.isHidden = false
                self?.serviceLbl.isHidden = true
            }
        }
    }
}
