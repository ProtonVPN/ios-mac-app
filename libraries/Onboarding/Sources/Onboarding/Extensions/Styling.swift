//
//  Created on 03.01.2022.
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

var colors: Colors!

let baseButtonStyle: (UIButton) -> Void = {
    $0.layer.cornerRadius = 8
    $0.titleLabel?.font = .systemFont(ofSize: 17)
    $0.setTitleColor(colors.text, for: .normal)
}

let brandStyle: (UIView) -> Void = {
    $0.backgroundColor = colors.brand
}

let actionButtonStyle =
    baseButtonStyle <> brandStyle
    <> {
        $0.heightAnchor.constraint(equalToConstant: 48).isActive = true
}

let textButtonStyle: (UIButton) -> Void = {
    $0.titleLabel?.font = .systemFont(ofSize: 17)
    $0.setTitleColor(colors.brand, for: .normal)
}

let actionTextButtonStyle =
    textButtonStyle
    <> {
        $0.titleLabel?.font = .systemFont(ofSize: 15)
}

let baseTextStyle: (UILabel) -> Void = {
    $0.font = .systemFont(ofSize: 17)
    $0.textColor = colors.text
    $0.numberOfLines = 0
}

let centeredTextStyle =
    baseTextStyle
    <> {
        $0.textAlignment = .center
}

let bigTitleStyle =
    centeredTextStyle
    <> {
        $0.font = .systemFont(ofSize: 28, weight: .bold)
}

let baseViewStyle: (UIView) -> Void = {
    $0.backgroundColor = colors.background
}

let tourStepHeaderStyle: (UIView) -> Void = {
    $0.backgroundColor = UIColor(red: 37 / 255, green: 39 / 255, blue: 44 / 255, alpha: 1)
}

let tourPagerStyle: (UIPageControl) -> Void = {
    $0.numberOfPages = TourStep.allCases.count
    $0.currentPageIndicatorTintColor = colors.brand
    $0.pageIndicatorTintColor = UIColor(red: 48 / 255, green: 50 / 255, blue: 57 / 255, alpha: 1)
}

let titleStyle =
    centeredTextStyle
    <> {
        $0.font = .systemFont(ofSize: 22, weight: .bold)
}

let plusOnlyStyle =
    brandStyle
    <> {
        $0.layer.cornerRadius = 9
}

let plusOnlyTextStyle =
    baseTextStyle
    <> {
        $0.font = .systemFont(ofSize: 11, weight: .semibold)
}

let textNoteStyle =
    baseTextStyle <> centeredTextStyle
    <> {
        $0.font = .systemFont(ofSize: 15)
        $0.textColor = colors.weakText
}

let textSubNoteStyle =
    textNoteStyle
    <> {
        $0.font = .systemFont(ofSize: 13, weight: .semibold)
}

let countryTextStyle =
    baseTextStyle
    <> {
        $0.font = .systemFont(ofSize: 15, weight: .semibold)
}

let secondaryViewStyle: (UIView) -> Void = {
    $0.backgroundColor = colors.secondaryBackground
}

let countryViewStyle =
    secondaryViewStyle
    <> {
        $0.layer.cornerRadius = 8
}

let pageTitleStyle =
    bigTitleStyle
    <> {
        $0.textAlignment = .left
}

let footerStyle =
    baseTextStyle
    <> {
        $0.textColor = colors.weakText
        $0.font = .systemFont(ofSize: 13)
}

let navigationStyle: (UINavigationController) -> Void = {
    $0.navigationBar.backgroundColor = colors.background
    $0.navigationBar.isTranslucent = false
    $0.modalPresentationStyle = .fullScreen
}

let notificationViewStyle: (UIView) -> Void = {
    $0.layer.cornerRadius = 8
    $0.backgroundColor = colors.notification
}

let notificationTextStyle: (UILabel) -> Void = {
    $0.font = UIFont.systemFont(ofSize: 15)
    $0.textColor = colors.textInverted
    $0.numberOfLines = 0
}
