//
//  AnnotationViewModel.swift
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
import CoreLocation
import LegacyCommon
import Localization
import Strings

enum AnnotationViewState {
    case idle
    case selected
}

protocol AnnotationViewModel {
    var countryCode: String { get }
    var coordinate: CLLocationCoordinate2D { get }
    
    var buttonStateChanged: (() -> Void)? { get set }
    
    var available: Bool { get }
    
    var isConnected: Bool { get }
    var isConnecting: Bool { get }
    var connectedUiState: Bool { get }
    var connectIconTint: UIColor { get }
    var connectIcon: UIImage? { get }
    
    var viewState: AnnotationViewState { get set }
    
    var minPinHeight: CGFloat { get }
    var maxPinHeight: CGFloat { get }
    var pinHeight: CGFloat { get }
    var outlineWidth: CGFloat { get }
    var outlineColor: UIColor { get }
    var labelString: NSAttributedString { get }
    var accessibilityLabel: String { get }
    var labelHeight: CGFloat { get }
    var labelStringPadding: CGFloat { get }
    var labelWidth: CGFloat { get }
    var labelColor: UIColor { get }
    var hideLabel: Bool { get }
    
    var maxHeight: CGFloat { get }
    var anchorPoint: CGPoint { get }
    
    var flag: UIImage? { get }
    var flagOverlayColor: UIColor { get }
    
    var showAnchor: Bool { get }
    
    func tapped()
}

extension AnnotationViewModel {
    var connectedUiState: Bool { // ui connected state
        isConnected || isConnecting
    }
    
    var pinHeight: CGFloat {
        switch viewState {
        case .idle:
            minPinHeight
        case .selected:
            maxPinHeight
        }
    }
    
    var outlineWidth: CGFloat {
        2
    }

    private var localizedCountry: String? {
        LocalizationUtility.default.countryName(forCode: countryCode)
    }

    var accessibilityLabel: String {
        localizedCountry ?? ""
    }
    
    var labelString: NSAttributedString {
        (localizedCountry ?? "").attributed(withColor: .normalTextColor(), fontSize: 18, alignment: .center)
    }
    
    var labelHeight: CGFloat {
        36
    }
    
    var labelStringPadding: CGFloat {
        labelHeight - labelString.size().height
    }
    
    var labelWidth: CGFloat {
        let textWidth = 2 * round((labelString.size().width + labelStringPadding * 2) / 2)
        return textWidth > maxPinHeight ? textWidth : maxPinHeight
    }
    
    var hideLabel: Bool {
        viewState == .idle
    }
    
    var maxHeight: CGFloat {
        maxPinHeight + labelHeight
    }
    
    var flag: UIImage? {
        UIImage.flag(countryCode: countryCode)
    }
}
