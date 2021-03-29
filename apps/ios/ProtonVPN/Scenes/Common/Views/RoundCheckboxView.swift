//
//  RoundCheckbox.swift
//  ProtonVPN - Created on 30/08/2019.
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

class RoundCheckboxView: UIView {

    enum State {
        case off
        case on
    }
    
    public var state: State = .off {
        didSet {
            setupView()
        }
    }
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var backgroundView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
        setupCorners()
    }
    
    private func setupView() {
        self.backgroundColor = .protonTransparent()
        switch state {
        case .on:
            backgroundView.backgroundColor = .protonGreen()
        case .off:
            backgroundView.backgroundColor = .protonWhite()
        }
    }
    
    private func setupCorners() {
        backgroundView.layer.masksToBounds = true
        backgroundView.layer.cornerRadius = self.frame.size.width / 2
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setupCorners()
    }

}
