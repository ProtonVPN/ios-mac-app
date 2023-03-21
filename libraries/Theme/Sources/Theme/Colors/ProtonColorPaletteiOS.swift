//
//  ColorPaletteiOS.swift
//  ProtonCore-UIFoundations - Created on 04.11.20.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

public struct ColorPaletteiOS {
    public static let instance = ColorPaletteiOS()

    private init() {}

    // MARK: MobileBrand
    public let BrandDarken40 = Asset.mobileBrandDarken40.color
    public let BrandDarken20 = Asset.mobileBrandDarken20.color
    public let BrandNorm = Asset.mobileBrandNorm.color
    public let BrandLighten20 = Asset.mobileBrandLighten20.color
    public let BrandLighten40 = Asset.mobileBrandLighten40.color

    // MARK: Notification
    public var NotificationError: ColorAsset.Color {
        Asset.mobileNotificationError.color
    }
    public var NotificationWarning: ColorAsset.Color {
        Asset.mobileNotificationWarning.color
    }
    public var NotificationSuccess: ColorAsset.Color {
        Asset.mobileNotificationSuccess.color
    }
    public var NotificationNorm: ColorAsset.Color {
        Asset.mobileNotificationNorm.color
    }

    // MARK: Interaction norm
    public let InteractionNorm = Asset.mobileInteractionNorm.color
    public let InteractionNormPressed = Asset.mobileInteractionNormPressed.color
    public let InteractionNormDisabled = Asset.mobileInteractionNormDisabled.color

    // MARK: Shade
    public var Shade100: ColorAsset.Color {
        Asset.mobileShade100.color
    }
    public var Shade80: ColorAsset.Color {
        Asset.mobileShade80.color
    }
    public var Shade60: ColorAsset.Color {
        Asset.mobileShade60.color
    }
    public var Shade50: ColorAsset.Color {
        Asset.mobileShade50.color
    }
    public var Shade40: ColorAsset.Color {
        Asset.mobileShade40.color
    }
    public var Shade20: ColorAsset.Color {
        Asset.mobileShade20.color
    }
    public var Shade15: ColorAsset.Color {
        Asset.mobileShade15.color
    }
    public var Shade10: ColorAsset.Color {
        Asset.mobileShade10.color
    }
    public var Shade0: ColorAsset.Color {
        Asset.mobileShade0.color
    }

    // MARK: Text
    public var TextNorm: ColorAsset.Color {
        Asset.mobileTextNorm.color
    }
    public var TextWeak: ColorAsset.Color {
        Asset.mobileTextWeak.color
    }
    public var TextHint: ColorAsset.Color {
        Asset.mobileTextHint.color
    }
    public var TextDisabled: ColorAsset.Color {
        Asset.mobileTextDisabled.color
    }
    public var TextInverted: ColorAsset.Color {
        Asset.mobileTextInverted.color
    }
    public var TextAccent: ColorAsset.Color {
        Asset.mobileTextAccent.color
    }

    // MARK: Icon
    public var IconNorm: ColorAsset.Color {
        Asset.mobileIconNorm.color
    }
    public var IconWeak: ColorAsset.Color {
        Asset.mobileIconWeak.color
    }
    public var IconHint: ColorAsset.Color {
        Asset.mobileIconHint.color
    }
    public var IconDisabled: ColorAsset.Color {
        Asset.mobileIconDisabled.color
    }
    public var IconInverted: ColorAsset.Color {
        Asset.mobileIconInverted.color
    }
    public var IconAccent: ColorAsset.Color {
        Asset.mobileIconAccent.color
    }

    // MARK: Interaction
    public var InteractionWeak: ColorAsset.Color {
        Asset.mobileInteractionWeak.color
    }
    public var InteractionWeakPressed: ColorAsset.Color {
        Asset.mobileInteractionWeakPressed.color
    }
    public var InteractionWeakDisabled: ColorAsset.Color {
        Asset.mobileInteractionWeakDisabled.color
    }
    public var InteractionStrong: ColorAsset.Color {
        Asset.mobileInteractionStrong.color
    }
    public var InteractionStrongPressed: ColorAsset.Color {
        Asset.mobileInteractionStrongPressed.color
    }

    // MARK: Floaty
    public let FloatyBackground = Asset.mobileFloatyBackground.color
    public let FloatyPressed = Asset.mobileFloatyPressed.color
    public let FloatyText = Asset.mobileFloatyText.color

    // MARK: Background
    public var BackgroundNorm: ColorAsset.Color {
        Asset.mobileBackgroundNorm.color
    }
    public var BackgroundDeep: ColorAsset.Color {
        Asset.mobileBackgroundDeep.color
    }
    public var BackgroundSecondary: ColorAsset.Color {
        Asset.mobileBackgroundSecondary.color
    }

    // MARK: Separator
    public var SeparatorNorm: ColorAsset.Color {
        Asset.mobileSeparatorNorm.color
    }

    // MARK: Sidebar
    public var SidebarBackground: ColorAsset.Color {
        Asset.mobileSidebarBackground.color
    }
    public var SidebarInteractionWeakNorm: ColorAsset.Color {
        Asset.mobileSidebarInteractionWeakNorm.color
    }
    public var SidebarInteractionWeakPressed: ColorAsset.Color {
        Asset.mobileSidebarInteractionWeakPressed.color
    }
    public var SidebarSeparator: ColorAsset.Color {
        Asset.mobileSidebarSeparator.color
    }
    public var SidebarTextNorm: ColorAsset.Color {
        Asset.mobileSidebarTextNorm.color
    }
    public var SidebarTextWeak: ColorAsset.Color {
        Asset.mobileSidebarTextWeak.color
    }
    public var SidebarIconNorm: ColorAsset.Color {
        Asset.mobileSidebarIconNorm.color
    }
    public var SidebarIconWeak: ColorAsset.Color {
        Asset.mobileSidebarIconWeak.color
    }
    public let SidebarInteractionPressed = Asset.mobileSidebarInteractionPressed.color

    // MARK: Blenders
    public let BlenderNorm = Asset.mobileBlenderNorm.color

    // MARK: Accent
    public let PurpleBase = Asset.sharedPurpleBase.color
    public let EnzianBase = Asset.sharedEnzianBase.color
    public let PinkBase = Asset.sharedPinkBase.color
    public let PlumBase = Asset.sharedPlumBase.color
    public let StrawberryBase = Asset.sharedStrawberryBase.color
    public let CeriseBase = Asset.sharedCeriseBase.color
    public let CarrotBase = Asset.sharedCarrotBase.color
    public let CopperBase = Asset.sharedCopperBase.color
    public let SaharaBase = Asset.sharedSaharaBase.color
    public let SoilBase = Asset.sharedSoilBase.color
    public let SlateblueBase = Asset.sharedSlateblueBase.color
    public let CobaltBase = Asset.sharedCobaltBase.color
    public let PacificBase = Asset.sharedPacificBase.color
    public let OceanBase = Asset.sharedOceanBase.color
    public let ReefBase = Asset.sharedReefBase.color
    public let PineBase = Asset.sharedPineBase.color
    public let FernBase = Asset.sharedFernBase.color
    public let ForestBase = Asset.sharedForestBase.color
    public let OliveBase = Asset.sharedOliveBase.color
    public let PickleBase = Asset.sharedPickleBase.color

    // MARK: Two special colors that consistently occur in designs even though they are not part of the palette
    public let White = Asset.white.color
    public let Black = Asset.black.color

    // MARK: Special banner colors
    public let Ebb = Asset.ebb.color
    public let Cloud = Asset.cloud.color
}

// Two special global colors

extension ColorPaletteiOS {
    private var balticSea: Int { 0x1C1B24 }
    private var bastille: Int { 0x292733 }
    private var steelGray: Int { 0x343140 }
    private var blackcurrant: Int { 0x3B3747 }
    private var gunPowder: Int { 0x4A4658 }
    private var smoky: Int { 0x5B576B }
    private var dolphin: Int { 0x6D697D }
    private var cadetBlue: Int { 0xA7A4B5 }
    private var cinder: Int { 0x0C0C14 }
    private var shipGray: Int { 0x35333D }
    private var doveGray: Int { 0x706D6B }
    private var dawn: Int { 0x999693 }
    private var cottonSeed: Int { 0xC2BFBC }
    private var cloud: Int { 0xD1CFCD }
    private var ebb: Int { 0xEAE7E4 }
    private var cararra: Int { 0xF5F4F2 }
    private var haiti: Int { 0x1B1340 }
    private var valhalla: Int { 0x271B54 }
    private var jacarta: Int { 0x2E2260 }
    private var pomegranate: Int { 0xCC2D4F }
    private var mauvelous: Int { 0xF08FA4 }
    private var sunglow: Int { 0xE65200 }
    private var texasRose: Int { 0xFFB84D }
    private var apple: Int { 0x007B58 }
    private var puertoRico: Int { 0x4AB89A }
    private var white: Int { 0xFFFFFF }
    private var pampas: Int { 0xF1EEEB }

    private var shade100Vpn: Int { white }
    private var shade80Vpn: Int { cadetBlue }
    private var shade60Vpn: Int { dolphin }
    private var shade50Vpn: Int { smoky }
    private var shade40Vpn: Int { gunPowder }
    private var shade20Vpn: Int { blackcurrant }
    private var shade15Vpn: Int { bastille }
    private var shade10Vpn: Int { balticSea }
    private var shade0Vpn: Int { cinder }
    private var textNormVpn: Int { shade100Vpn }
    private var textWeakVpn: Int { shade80Vpn }
    private var textHintVpn: Int { shade60Vpn }
    private var textDisabledVpn: Int { shade50Vpn }
    private var textInvertedVpn: Int { shade0Vpn }
    private var textAccentVpn: Int { 0x8A6EFF }
    private var iconNormVpn: Int { shade100Vpn }
    private var iconWeakVpn: Int { shade80Vpn }
    private var iconHintVpn: Int { shade60Vpn }
    private var iconDisabledVpn: Int { shade50Vpn }
    private var iconInvertedVpn: Int { shade0Vpn }
    private var iconAccentVpn: Int { 0x8A6EFF }
    private var interactionWeakVpn: Int { shade20Vpn }
    private var interactionWeakPressedVpn: Int { shade40Vpn }
    private var interactionWeakDisabledVpn: Int { shade10Vpn }
    private var interactionStrongVpn: Int { shade100Vpn }
    private var interactionStrongPressedVpn: Int { shade80Vpn }
    private var backgroundNormVpn: Int { shade10Vpn }
    private var backgroundDeepVpn: Int { shade0Vpn }
    private var backgroundSecondaryVpn: Int { shade15Vpn }
    private var separatorNormVpn: Int { shade20Vpn }
    private var notificationErrorVpn: Int { mauvelous }
    private var notificationWarningVpn: Int { texasRose }
    private var notificationSuccessVpn: Int { puertoRico }
    private var notificationNormVpn: Int { shade100Vpn }
    private var sidebarBackgroundVpn: Int { cinder }
    private var sidebarInteractionWeakNormVpn: Int { blackcurrant }
    private var sidebarInteractionWeakPressedVpn: Int { gunPowder }
    private var sidebarSeparatorVpn: Int { blackcurrant }
    private var sidebarTextNormVpn: Int { white }
    private var sidebarTextWeakVpn: Int { cadetBlue }
    private var sidebarIconNormVpn: Int { shade100Vpn }
    private var sidebarIconWeakVpn: Int { cadetBlue }
}
