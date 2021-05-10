//
//  ConnectionOverlay.swift
//  ProtonVPN - Created on 27.06.19.
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

class ConnectionOverlay: NSView {

    let fullBlurRadius = 4.0
    
    var blurRadius = 4.0
    var blurReduction: Double?
    var blurReductionTimer: Timer?
    var stopAnimatingTimer: Timer?
    var blurReductionCompletion: (() -> Void)?
    
    override var isHidden: Bool {
        didSet {
            setup()
        }
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        
        setup()
    }
    
    func removeBlur(over time: TimeInterval, completion: @escaping () -> Void) {
        stopAnimating()
        
        blurReduction = fullBlurRadius / (time * 60)
        blurReductionCompletion = completion
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            self.blurReductionTimer = Timer.scheduledTimer(timeInterval: 1 / 60, target: self, selector: #selector(self.reduceBlur), userInfo: nil, repeats: true)
            self.stopAnimatingTimer = Timer.scheduledTimer(timeInterval: time, target: self, selector: #selector(self.stopAnimating), userInfo: nil, repeats: false)
        }
    }
    
    func stopBlurAnimation() {
        guard let timer = blurReductionTimer else { return }
        
        if timer.isValid {
            stopAnimating()
        }
    }
    
    private func buildLayerBlurEffect() {
        layer?.masksToBounds = true
        
        layer?.needsDisplayOnBoundsChange = true
        
        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setDefaults()
        blurFilter.setValue(NSNumber(value: blurRadius), forKey: "inputRadius")
        layer?.backgroundFilters = [blurFilter]
        
        layer?.setNeedsDisplay()
    }
    
    private func removeLayerBlurEffects() {
        layer?.needsDisplayOnBoundsChange = false
    }
    
    private func setup() {
        let blurLayer = CALayer()
        wantsLayer = true
        layer = blurLayer
        
        if !isHidden {
            buildLayerBlurEffect()
        } else {
            removeLayerBlurEffects()
        }
    }
    
    @objc private func reduceBlur() {
        guard let blurReduction = blurReduction else { return }
        
        if (blurRadius - blurReduction) > 0.0 {
            blurRadius -= blurReduction
        }
    }
    
    @objc private func stopAnimating() {
        blurReductionTimer?.invalidate()
        stopAnimatingTimer?.invalidate()
        blurRadius = fullBlurRadius
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            self.blurReductionCompletion?()
            self.blurReductionCompletion = nil
        }
    }
}
