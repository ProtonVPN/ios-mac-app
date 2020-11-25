//
//  NSView+Extension.swift
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

extension NSView {
    
    func animateBackgroundColor(_ color: NSColor, delegate: AnyObject? = nil) {
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.toValue = color.cgColor
        animation.duration = 0.2
        animation.repeatCount = 0
        
        if let delegate: AnyObject = delegate {
            animation.delegate = delegate as? CAAnimationDelegate
        }
        
        layer?.add(animation, forKey: nil)
    }
    
    func pin(viewController: NSViewController) {
        addSubview(viewController.view)
        
        NSLayoutConstraint(item: viewController.view,
                           attribute: NSLayoutConstraint.Attribute.top,
                           relatedBy: NSLayoutConstraint.Relation.equal,
                           toItem: self,
                           attribute: NSLayoutConstraint.Attribute.top,
                           multiplier: 1.0,
                           constant: 0.0).isActive = true
        
        NSLayoutConstraint(item: viewController.view,
                           attribute: NSLayoutConstraint.Attribute.trailing,
                           relatedBy: NSLayoutConstraint.Relation.equal,
                           toItem: self,
                           attribute: NSLayoutConstraint.Attribute.trailing,
                           multiplier: 1.0,
                           constant: 0.0).isActive = true
        
        NSLayoutConstraint(item: viewController.view,
                           attribute: NSLayoutConstraint.Attribute.bottom,
                           relatedBy: NSLayoutConstraint.Relation.equal,
                           toItem: self,
                           attribute: NSLayoutConstraint.Attribute.bottom,
                           multiplier: 1.0,
                           constant: 0.0).isActive = true
        
        NSLayoutConstraint(item: viewController.view,
                           attribute: NSLayoutConstraint.Attribute.leading,
                           relatedBy: NSLayoutConstraint.Relation.equal,
                           toItem: self,
                           attribute: NSLayoutConstraint.Attribute.leading,
                           multiplier: 1.0,
                           constant: 0.0).isActive = true
    }
    
    func pinTo(view: NSView) {
        NSLayoutConstraint(item: view,
                           attribute: NSLayoutConstraint.Attribute.top,
                           relatedBy: NSLayoutConstraint.Relation.equal,
                           toItem: self,
                           attribute: NSLayoutConstraint.Attribute.top,
                           multiplier: 1.0,
                           constant: 0.0).isActive = true
        
        NSLayoutConstraint(item: view,
                           attribute: NSLayoutConstraint.Attribute.trailing,
                           relatedBy: NSLayoutConstraint.Relation.equal,
                           toItem: self,
                           attribute: NSLayoutConstraint.Attribute.trailing,
                           multiplier: 1.0,
                           constant: 0.0).isActive = true
        
        NSLayoutConstraint(item: view,
                           attribute: NSLayoutConstraint.Attribute.bottom,
                           relatedBy: NSLayoutConstraint.Relation.equal,
                           toItem: self,
                           attribute: NSLayoutConstraint.Attribute.bottom,
                           multiplier: 1.0,
                           constant: 0.0).isActive = true
        
        NSLayoutConstraint(item: view,
                           attribute: NSLayoutConstraint.Attribute.leading,
                           relatedBy: NSLayoutConstraint.Relation.equal,
                           toItem: self,
                           attribute: NSLayoutConstraint.Attribute.leading,
                           multiplier: 1.0,
                           constant: 0.0).isActive = true
    }
    
    func fillVertically(withViews views: [NSView]) {
        var lastView: NSView?
        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(view)
            
            if lastView == nil { // first row
                NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1.0, constant: 0.0).isActive = true
            } else {
                NSLayoutConstraint(item: lastView!, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1.0, constant: 0.0).isActive = true
            }
            NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1.0, constant: 0.0).isActive = true
            
            NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1.0, constant: 0.0).isActive = true
            
            lastView = view
        }
        if lastView != nil {
            NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: lastView, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1.0, constant: 0.0).isActive = true
        }
    }
    
    func  setHeightConstraint( _ height: CGFloat ) {
        NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: height).isActive = true
    }
    
    static var identifierString: String {
        return String(describing: self)
    }
    
    static var identifier: NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier(rawValue: identifierString)
    }
    
    static var nib: NSNib? {
        return NSNib(nibNamed: identifierString, bundle: nil)
    }
    
    /// Load a view from nib/xib file that is named the same as the class itself
    static func loadViewFromNib<T>() -> T? {
        var nibObjects: NSArray?
        let nibName = identifierString
        
        if Bundle.main.loadNibNamed(nibName, owner: self, topLevelObjects: &nibObjects) {
            guard let nibObjects = nibObjects else { return nil }
            let viewObjects = nibObjects.filter { $0 is T }
            
            if !viewObjects.isEmpty {
                guard let view = viewObjects[0] as? T else { return nil }
                return view
            }
        }
        return nil
    }
    
}
