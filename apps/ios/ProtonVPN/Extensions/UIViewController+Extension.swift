//
//  UIViewController+Extension.swift
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

extension UIViewController {
    
    func changeConstraintBasedOnKeyboardChange(_ notification: Notification, constraint: NSLayoutConstraint, maxConstraintConstant: CGFloat) {
        guard let info = notification.userInfo,
            let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
            let animationCurveRaw = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue,
            let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        // FUTUREFIX: iPad split keyboard
        //        let endFrameInWindow: CGRect = view.convert(endFrame, from: view.window)
        
        let animationOptions = UIView.AnimationOptions(rawValue: UIView.AnimationOptions.beginFromCurrentState.rawValue | animationCurveRaw << 16)
        
        if endFrame.minY >= UIScreen.main.bounds.maxY { // keyboard disappearing
            constraint.constant = maxConstraintConstant
        } else {
            let padding: CGFloat = UIDevice.current.screenType == .iPhones_5_5s_5c_SE ? 5.0 : 20.0
            constraint.constant = endFrame.size.height + padding
        }
        
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: animationOptions,
                       animations: { [unowned self] in self.view.layoutIfNeeded() },
                       completion: nil)
    }
    
}
