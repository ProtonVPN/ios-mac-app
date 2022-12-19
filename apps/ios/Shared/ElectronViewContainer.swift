//
//  ElectronViewContainer.swift
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

class ElectronViewContainer: UIView {
    
    private let electron = UIView()
    
    var padding = UIEdgeInsets.zero // FUTUREDO: use padding to indent all calculations from the edge of the image
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        electron.isHidden = true
        electron.backgroundColor = .brandColor()
        electron.isUserInteractionEnabled = false
        addSubview(electron)
    }
    
    func animate() {
        guard electron.isHidden, electron.layer.animationKeys() == nil else {
            return // animation already running
        }
        
        let electronPoint1 = CGPoint(x: (self.frame.width * 0.124), y: (self.frame.height * 0.337))
        let electronPoint2 = CGPoint(x: (self.frame.width * 0.615), y: (self.frame.height * 0.891))
        let electronPoint3 = CGPoint(x: (self.frame.width * 0.881), y: (self.frame.height * 0.109))
        let electronWidth1: CGFloat = frame.width * 0.4
        let electronWidth2: CGFloat = frame.width * 0.15
        let electronWidth3: CGFloat = frame.width * 0.25
        
        electron.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: electronWidth1, height: electronWidth1))
        electron.layer.cornerRadius = electronWidth1 / 2
        electron.center = electronPoint1
        
        self.electron.isHidden = false
        let options = UIView.KeyframeAnimationOptions([UIView.KeyframeAnimationOptions.repeat, UIView.KeyframeAnimationOptions.calculationModeLinear])
        UIView.animateKeyframes(withDuration: 2.2, delay: 0, options: options, animations: {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.3, animations: {
                self.electron.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: electronWidth2, height: electronWidth2))
                self.electron.layer.cornerRadius = electronWidth2 / 2
                self.electron.center = electronPoint2
            })
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.4, animations: {
                self.electron.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: electronWidth3, height: electronWidth3))
                self.electron.layer.cornerRadius = electronWidth3 / 2
                self.electron.center = electronPoint3
            })
            UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3, animations: {
                self.electron.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: electronWidth1, height: electronWidth1))
                self.electron.layer.cornerRadius = electronWidth1 / 2
                self.electron.center = electronPoint1
            })
        }, completion: nil)
    }
    
    func stopAnimating() {
        electron.layer.removeAllAnimations()
        electron.isHidden = true
    }
}
