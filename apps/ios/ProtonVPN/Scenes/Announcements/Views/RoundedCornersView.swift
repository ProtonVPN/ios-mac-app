//
//  RoundedCornersView.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 05.10.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import UIKit

final class RoundedCornersView: UIView {
    override var bounds: CGRect {
        didSet {
            layer.cornerRadius = bounds.height / 2
        }
    }
}
