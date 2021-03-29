//
//  BadgedBarButtonItem.swift
//  ProtonVPN - Created on 2020-10-22.
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

class BadgedBarButtonItem: UIBarButtonItem {
    
    public var badgeColor: UIColor = .protonGreen()
    public var showBadge: Bool = false {
        didSet {
            badgeView.isHidden = !showBadge
        }
    }
    
    public var onTouchUpInside: (() -> Void)?
    
    private var button = UIButton()
    private var badgeView = UIView()
    
    init(withImage image: UIImage?) {
        super.init()
        setupView(withImage: image)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView(withImage image: UIImage?) {
        button.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
        button.setImage(image, for: .normal)
        
        badgeView.frame = CGRect(x: 12, y: 0, width: 10, height: 10)
        badgeView.backgroundColor = badgeColor
        badgeView.clipsToBounds = true
        badgeView.layer.cornerRadius = badgeView.frame.width / 2
        button.addSubview(badgeView)
        
        self.customView = button
    }
    
    @objc func buttonPressed() {
        onTouchUpInside?()
    }
    
}
