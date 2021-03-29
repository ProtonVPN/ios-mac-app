//
//  LoginBoxView.swift
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
import vpncore

class LoginBoxView: UIView {
    
    let height: CGFloat = 77.5
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }
    
    var buttons: [UIButton]? {
        let signUpButton = self.subviews[0].subviews[0] as! ProtonButton
        signUpButton.setTitle(LocalizedString.signUp, for: .normal)
        
        let loginButton = self.subviews[0].subviews[1] as! ProtonButton
        loginButton.setTitle(LocalizedString.logIn, for: .normal)
        
        return [signUpButton, loginButton]
    }
    
    private func setupView() {
        let shadow = self.subviews[1]
        shadow.backgroundColor = .protonLightGrey()
        
        self.backgroundColor = UIColor.protonLightGrey().withAlphaComponent(0.8)
    }
    
}
