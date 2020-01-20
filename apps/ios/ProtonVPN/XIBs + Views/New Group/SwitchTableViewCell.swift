//
//  SwitchTableViewCell.swift
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

class SwitchTableViewCell: UITableViewCell {

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var switchControl: UISwitch!
    
    var toggled: ((Bool) -> Void)?
    
    func toggleSelection() {
        let oldValue = switchControl.isOn
        switchControl.setOn(!oldValue, animated: true)
        switchControl.sendActions(for: .valueChanged)
        
        toggled?(switchControl.isOn)
    }
    
    @IBAction func toggle(_ sender: Any) {
        toggled?(switchControl.isOn)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.isSelected = false
        
        backgroundColor = .protonGrey()
        label.textColor = .white 
        selectionStyle = .none
    }
    
}
