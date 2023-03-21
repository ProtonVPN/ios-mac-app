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

public struct ProtonColorPalettemacOS {
    static let instance = ProtonColorPalettemacOS()

    private init() {}
    
    // MARK: - Backdrop
    public let BackdropNorm = Asset.protonCarbonBackdropNorm.color
    
    // MARK: - Background
    public let BackgroundNorm = Asset.protonCarbonBackgroundNorm.color
    public let BackgroundStrong = Asset.protonCarbonBackgroundStrong.color
    public let BackgroundWeak = Asset.protonCarbonBackgroundWeak.color
    
    // MARK: - Border
    public let BorderNorm = Asset.protonCarbonBorderNorm.color
    public let BorderWeak = Asset.protonCarbonBorderWeak.color
    
    // MARK: - Field
    public let FieldDisabled = Asset.protonCarbonFieldDisabled.color
    public let FieldFocus = Asset.protonCarbonFieldFocus.color
    public let FieldHighlight = Asset.protonCarbonFieldHighlight.color
    public let FieldHighlightError = Asset.protonCarbonFieldHighlightError.color
    public let FieldHover = Asset.protonCarbonFieldHover.color
    public let FieldNorm = Asset.protonCarbonFieldNorm.color
    
    // MARK: - Interaction
    public let InteractionDefault = Asset.protonCarbonInteractionDefault.color
    public let InteractionDefaultActive = Asset.protonCarbonInteractionDefaultActive.color
    public let InteractionDefaultHover = Asset.protonCarbonInteractionDefaultHover.color
    public let InteractionNorm = Asset.protonCarbonInteractionNorm.color
    public let InteractionNormActive = Asset.protonCarbonInteractionNormActive.color
    public let InteractionNormHover = Asset.protonCarbonInteractionNormHover.color
    public let InteractionWeak = Asset.protonCarbonInteractionWeak.color
    public let InteractionWeakActive = Asset.protonCarbonInteractionWeakActive.color
    public let InteractionWeakHover = Asset.protonCarbonInteractionWeakHover.color
    
    // MARK: - Link
    public let LinkActive = Asset.protonCarbonLinkActive.color
    public let LinkHover = Asset.protonCarbonLinkHover.color
    public let LinkNorm = Asset.protonCarbonLinkNorm.color
    
    // MARK: - Primary
    public let Primary = Asset.protonCarbonPrimary.color
    
    // MARK: - Shade
    public let Shade0 = Asset.protonCarbonShade0.color
    public let Shade10 = Asset.protonCarbonShade10.color
    public let Shade20 = Asset.protonCarbonShade20.color
    public let Shade40 = Asset.protonCarbonShade40.color
    public let Shade50 = Asset.protonCarbonShade50.color
    public let Shade60 = Asset.protonCarbonShade60.color
    public let Shade80 = Asset.protonCarbonShade80.color
    public let Shade100 = Asset.protonCarbonShade100.color
    
    // MARK: - Shadow
    public let ShadowLifted = Asset.protonCarbonShadowLifted.color
    public let ShadowNorm = Asset.protonCarbonShadowNorm.color
    
    // MARK: - Signal
    public let SignalDanger = Asset.protonCarbonSignalDanger.color
    public let SignalDangerActive = Asset.protonCarbonSignalDangerActive.color
    public let SignalDangerHover = Asset.protonCarbonSignalDangerHover.color
    public let SignalInfo = Asset.protonCarbonSignalInfo.color
    public let SignalInfoActive = Asset.protonCarbonSignalInfoActive.color
    public let SignalInfoHover = Asset.protonCarbonSignalInfoHover.color
    public let SignalSuccess = Asset.protonCarbonSignalSuccess.color
    public let SignalSuccessActive = Asset.protonCarbonSignalSuccessActive.color
    public let SignalSuccessHover = Asset.protonCarbonSignalSuccessHover.color
    public let SignalWarning = Asset.protonCarbonSignalWarning.color
    public let SignalWarningActive = Asset.protonCarbonSignalWarningActive.color
    public let SignalWarningHover = Asset.protonCarbonSignalWarningHover.color
    
    // MARK: - Text
    public let TextDisabled = Asset.protonCarbonTextDisabled.color
    public let TextHint = Asset.protonCarbonTextHint.color
    public let TextInvert = Asset.protonCarbonTextInvert.color
    public let TextNorm = Asset.protonCarbonTextNorm.color
    public let TextWeak = Asset.protonCarbonTextWeak.color
    
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
    
    // MARK: Two special colors that consistently occur in designs even though they are not part af the palette
    public let White = Asset.white.color
    public let Black = Asset.black.color
}
