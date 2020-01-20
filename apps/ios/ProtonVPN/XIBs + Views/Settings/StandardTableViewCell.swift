//
//  StandardTableViewCell.swift
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

class StandardTableViewCell: UITableViewCell {

    @IBOutlet weak var label: UILabel! // need to use a custom label instead of the built in title label to avoid an upper separator
    
    var completionHandler: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .protonGrey()
        label?.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .protonWhite()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        selectionStyle = .none
    }
    
    func select() {
        completionHandler?()
    }
    
}
