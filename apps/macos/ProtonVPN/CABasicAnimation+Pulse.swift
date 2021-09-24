//
//  CABasicAnimation+Pulse.swift
//  ProtonVPN-mac
//
//  Created by Jaroslav on 2021-09-23.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import QuartzCore

extension CABasicAnimation {
    
    /// Adds pulsing infinite animation to a given layet
    static func addPulseAnimation(_ layer: CALayer?, fromValue: Any = 1.0, toValue: Any = 0.9, duration: CFTimeInterval = 0.8, name: String = "pulse") {
        guard let layer = layer else {
            return
        }
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = fromValue
        animation.toValue = toValue
        animation.duration = duration
        animation.autoreverses = true
        animation.repeatCount = Float.infinity
        animation.timingFunction = CAMediaTimingFunction.init(name: .easeInEaseOut)
        
        layer.add(animation, forKey: "pulse")
    }
    
}
