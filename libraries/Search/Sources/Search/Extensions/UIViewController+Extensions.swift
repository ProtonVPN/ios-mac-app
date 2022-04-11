//
//  Created on 14.03.2022.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import UIKit

public extension UIViewController {
    func animateWithKeyboard(notification: NSNotification, animations: ((_ keyboardFrame: CGRect) -> Void)?) {
        guard let duration = notification.userInfo![UIResponder.keyboardAnimationDurationUserInfoKey] as? Double, let keyboardFrameValue = notification.userInfo![UIResponder.keyboardFrameEndUserInfoKey] as? NSValue, let curveValue = notification.userInfo![UIResponder.keyboardAnimationCurveUserInfoKey] as? Int, let curve = UIView.AnimationCurve(rawValue: curveValue) else {
            return
        }

        let animator = UIViewPropertyAnimator(duration: duration, curve: curve) { [weak self] in
            animations?(keyboardFrameValue.cgRectValue)
            self?.view?.layoutIfNeeded()
        }
        animator.startAnimation()
    }
}
