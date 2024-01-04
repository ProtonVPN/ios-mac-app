//
//  ProtonColorPalettemacOS.swift
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


#if canImport(Cocoa)

public struct ProtonColorPalettemacOS {
    public static let instance = ProtonColorPalettemacOS()

    private init() {}
    
    // MARK: - Backdrop
    public let BackdropNorm = Theme.Asset.protonCarbonBackdropNorm.color
    
    // MARK: - Background
    public let BackgroundNorm = Theme.Asset.protonCarbonBackgroundNorm.color
    public let BackgroundStrong = Theme.Asset.protonCarbonBackgroundStrong.color
    public let BackgroundWeak = Theme.Asset.protonCarbonBackgroundWeak.color
    
    // MARK: - Border
    public let BorderNorm = Theme.Asset.protonCarbonBorderNorm.color
    public let BorderWeak = Theme.Asset.protonCarbonBorderWeak.color
    
    // MARK: - Field
    public let FieldDisabled = Theme.Asset.protonCarbonFieldDisabled.color
    public let FieldFocus = Theme.Asset.protonCarbonFieldFocus.color
    public let FieldHighlight = Theme.Asset.protonCarbonFieldHighlight.color
    public let FieldHighlightError = Theme.Asset.protonCarbonFieldHighlightError.color
    public let FieldHover = Theme.Asset.protonCarbonFieldHover.color
    public let FieldNorm = Theme.Asset.protonCarbonFieldNorm.color
    
    // MARK: - Interaction
    public let InteractionDefault = Theme.Asset.protonCarbonInteractionDefault.color
    public let InteractionDefaultActive = Theme.Asset.protonCarbonInteractionDefaultActive.color
    public let InteractionDefaultHover = Theme.Asset.protonCarbonInteractionDefaultHover.color
    public let InteractionNorm = Theme.Asset.protonCarbonInteractionNorm.color
    public let InteractionNormActive = Theme.Asset.protonCarbonInteractionNormActive.color
    public let InteractionNormHover = Theme.Asset.protonCarbonInteractionNormHover.color
    public let InteractionWeak = Theme.Asset.protonCarbonInteractionWeak.color
    public let InteractionWeakActive = Theme.Asset.protonCarbonInteractionWeakActive.color
    public let InteractionWeakHover = Theme.Asset.protonCarbonInteractionWeakHover.color
    
    // MARK: - Link
    public let LinkActive = Theme.Asset.protonCarbonLinkActive.color
    public let LinkHover = Theme.Asset.protonCarbonLinkHover.color
    public let LinkNorm = Theme.Asset.protonCarbonLinkNorm.color
    
    // MARK: - Primary
    public let Primary = Theme.Asset.protonCarbonPrimary.color
    
    // MARK: - Shade
    public let Shade0 = Theme.Asset.protonCarbonShade0.color
    public let Shade10 = Theme.Asset.protonCarbonShade10.color
    public let Shade20 = Theme.Asset.protonCarbonShade20.color
    public let Shade40 = Theme.Asset.protonCarbonShade40.color
    public let Shade50 = Theme.Asset.protonCarbonShade50.color
    public let Shade60 = Theme.Asset.protonCarbonShade60.color
    public let Shade80 = Theme.Asset.protonCarbonShade80.color
    public let Shade100 = Theme.Asset.protonCarbonShade100.color
    
    // MARK: - Shadow
    public let ShadowLifted = Theme.Asset.protonCarbonShadowLifted.color
    public let ShadowNorm = Theme.Asset.protonCarbonShadowNorm.color
    
    // MARK: - Signal
    public let SignalDanger = Theme.Asset.protonCarbonSignalDanger.color
    public let SignalDangerActive = Theme.Asset.protonCarbonSignalDangerActive.color
    public let SignalDangerHover = Theme.Asset.protonCarbonSignalDangerHover.color
    public let SignalInfo = Theme.Asset.protonCarbonSignalInfo.color
    public let SignalInfoActive = Theme.Asset.protonCarbonSignalInfoActive.color
    public let SignalInfoHover = Theme.Asset.protonCarbonSignalInfoHover.color
    public let SignalSuccess = Theme.Asset.protonCarbonSignalSuccess.color
    public let SignalSuccessActive = Theme.Asset.protonCarbonSignalSuccessActive.color
    public let SignalSuccessHover = Theme.Asset.protonCarbonSignalSuccessHover.color
    public let SignalWarning = Theme.Asset.protonCarbonSignalWarning.color
    public let SignalWarningActive = Theme.Asset.protonCarbonSignalWarningActive.color
    public let SignalWarningHover = Theme.Asset.protonCarbonSignalWarningHover.color
    
    // MARK: - Text
    public let TextDisabled = Theme.Asset.protonCarbonTextDisabled.color
    public let TextHint = Theme.Asset.protonCarbonTextHint.color
    public let TextInvert = Theme.Asset.protonCarbonTextInvert.color
    public let TextNorm = Theme.Asset.protonCarbonTextNorm.color
    public let TextWeak = Theme.Asset.protonCarbonTextWeak.color
    
    // MARK: Accent
    public let PurpleBase = Theme.Asset.sharedPurpleBase.color
    public let EnzianBase = Theme.Asset.sharedEnzianBase.color
    public let PinkBase = Theme.Asset.sharedPinkBase.color
    public let PlumBase = Theme.Asset.sharedPlumBase.color
    public let StrawberryBase = Theme.Asset.sharedStrawberryBase.color
    public let CeriseBase = Theme.Asset.sharedCeriseBase.color
    public let CarrotBase = Theme.Asset.sharedCarrotBase.color
    public let CopperBase = Theme.Asset.sharedCopperBase.color
    public let SaharaBase = Theme.Asset.sharedSaharaBase.color
    public let SoilBase = Theme.Asset.sharedSoilBase.color
    public let SlateblueBase = Theme.Asset.sharedSlateblueBase.color
    public let CobaltBase = Theme.Asset.sharedCobaltBase.color
    public let PacificBase = Theme.Asset.sharedPacificBase.color
    public let OceanBase = Theme.Asset.sharedOceanBase.color
    public let ReefBase = Theme.Asset.sharedReefBase.color
    public let PineBase = Theme.Asset.sharedPineBase.color
    public let FernBase = Theme.Asset.sharedFernBase.color
    public let ForestBase = Theme.Asset.sharedForestBase.color
    public let OliveBase = Theme.Asset.sharedOliveBase.color
    public let PickleBase = Theme.Asset.sharedPickleBase.color
    
    // MARK: Two special colors that consistently occur in designs even though they are not part af the palette
    public let White = Theme.Asset.white.color
    public let Black = Theme.Asset.black.color
}

#endif
