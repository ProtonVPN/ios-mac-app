//
//  ProtonButton.swift
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

class ProtonButton: UIButton {
    
    enum CustomState {
        case primary // e.g. connect
        case secondary
        case destructive // e.g. disconnect or cancel
        case disabled
    }
    
    var customState: CustomState = .primary {
        didSet {
            update()
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            customState = isEnabled ? .primary : .disabled
        }
    }
    
    var activityIndicator: UIActivityIndicatorView?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setUpView()
    }
    
    init() {
        super.init(frame: .zero)
        setUpView()
    }
    
    private func setUpView() {
        clipsToBounds = true
        tintColor = .protonWhite()
        
        setTitleColor(.protonWhite(), for: .normal)
        
        update()
    }
    
    private func update() {
        switch customState {
        case .primary:
            backgroundColor = .protonGreen()
            layer.borderWidth = 0.0
            setTitleColor(.protonWhite(), for: .normal)
        case .secondary:
            backgroundColor = .clear
            layer.borderWidth = 1.0
            layer.borderColor = UIColor.protonUnavailableGrey().cgColor
            setTitleColor(.protonWhite(), for: .normal)
        case .destructive:
            backgroundColor = .protonUnavailableGrey()
            layer.borderWidth = 0.0
            setTitleColor(.protonBlack(), for: .normal)
        case .disabled:
            backgroundColor = .protonUnavailableGrey()
            layer.borderWidth = 0.0
            setTitleColor(.protonWhite(), for: .normal)
        }
        
        layer.cornerRadius = bounds.height / 2
    }
    
    func showLoading() {
        if (activityIndicator == nil) {
            activityIndicator = createActivityIndicator()
        }
        
        showSpinning()
    }
    
    func hideLoading() {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator?.stopAnimating()
        }
    }
    
    private func createActivityIndicator() -> UIActivityIndicatorView {
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .protonWhite()
        return activityIndicator
    }
    
    private func showSpinning() {
        guard let activityIndicator = activityIndicator else {
            return
        }
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(activityIndicator)
        centerActivityIndicatorInButton()
        activityIndicator.startAnimating()
    }
    
    private func centerActivityIndicatorInButton() {
        let xCenterConstraint = NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: activityIndicator, attribute: .leading, multiplier: 1, constant: -17)
        self.addConstraint(xCenterConstraint)
        
        let yCenterConstraint = NSLayoutConstraint(item: self, attribute: .centerY, relatedBy: .equal, toItem: activityIndicator, attribute: .centerY, multiplier: 1, constant: 0)
        self.addConstraint(yCenterConstraint)
    }
    
    // MARK: - Style
    
    public func styleCenterMultiline() {
        titleLabel?.lineBreakMode = .byWordWrapping
        titleLabel?.textAlignment = .center
    }
    
}
