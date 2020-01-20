//
//  PassThroughImageView.swift
//  ProtonVPN
//
//  Created by Robert Patchett on 6/02/18.
//  Copyright © 2018 ProtonVPN. All rights reserved.
//

import Cocoa

class PassThroughImageView: NSImageView {

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let view = super.hitTest(point) {
            if view == self {
                return nil
            } else {
                return view
            }
        }
        return nil
    }
}
