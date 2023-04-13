// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ColorAsset.Color", message: "This typealias will be removed in SwiftGen 7.0")
public typealias AssetColorTypeAlias = ColorAsset.Color

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
public enum Asset {
  public static let sharedCarrotBase = ColorAsset(name: "SharedCarrotBase")
  public static let sharedCeriseBase = ColorAsset(name: "SharedCeriseBase")
  public static let sharedCobaltBase = ColorAsset(name: "SharedCobaltBase")
  public static let sharedCopperBase = ColorAsset(name: "SharedCopperBase")
  public static let sharedEnzianBase = ColorAsset(name: "SharedEnzianBase")
  public static let sharedFernBase = ColorAsset(name: "SharedFernBase")
  public static let sharedForestBase = ColorAsset(name: "SharedForestBase")
  public static let sharedOceanBase = ColorAsset(name: "SharedOceanBase")
  public static let sharedOliveBase = ColorAsset(name: "SharedOliveBase")
  public static let sharedPacificBase = ColorAsset(name: "SharedPacificBase")
  public static let sharedPickleBase = ColorAsset(name: "SharedPickleBase")
  public static let sharedPineBase = ColorAsset(name: "SharedPineBase")
  public static let sharedPinkBase = ColorAsset(name: "SharedPinkBase")
  public static let sharedPlumBase = ColorAsset(name: "SharedPlumBase")
  public static let sharedPurpleBase = ColorAsset(name: "SharedPurpleBase")
  public static let sharedReefBase = ColorAsset(name: "SharedReefBase")
  public static let sharedSaharaBase = ColorAsset(name: "SharedSaharaBase")
  public static let sharedSlateblueBase = ColorAsset(name: "SharedSlateblueBase")
  public static let sharedSoilBase = ColorAsset(name: "SharedSoilBase")
  public static let sharedStrawberryBase = ColorAsset(name: "SharedStrawberryBase")
  public static let mobileBackgroundDeep = ColorAsset(name: "MobileBackgroundDeep")
  public static let mobileBackgroundNorm = ColorAsset(name: "MobileBackgroundNorm")
  public static let mobileBackgroundSecondary = ColorAsset(name: "MobileBackgroundSecondary")
  public static let mobileBlenderNorm = ColorAsset(name: "MobileBlenderNorm")
  public static let mobileBrandDarken20 = ColorAsset(name: "MobileBrandDarken20")
  public static let mobileBrandDarken40 = ColorAsset(name: "MobileBrandDarken40")
  public static let mobileBrandLighten20 = ColorAsset(name: "MobileBrandLighten20")
  public static let mobileBrandLighten40 = ColorAsset(name: "MobileBrandLighten40")
  public static let mobileBrandNorm = ColorAsset(name: "MobileBrandNorm")
  public static let mobileFloatyBackground = ColorAsset(name: "MobileFloatyBackground")
  public static let mobileFloatyPressed = ColorAsset(name: "MobileFloatyPressed")
  public static let mobileFloatyText = ColorAsset(name: "MobileFloatyText")
  public static let mobileIconAccent = ColorAsset(name: "MobileIconAccent")
  public static let mobileIconDisabled = ColorAsset(name: "MobileIconDisabled")
  public static let mobileIconHint = ColorAsset(name: "MobileIconHint")
  public static let mobileIconInverted = ColorAsset(name: "MobileIconInverted")
  public static let mobileIconNorm = ColorAsset(name: "MobileIconNorm")
  public static let mobileIconWeak = ColorAsset(name: "MobileIconWeak")
  public static let mobileInteractionStrong = ColorAsset(name: "MobileInteractionStrong")
  public static let mobileInteractionStrongPressed = ColorAsset(name: "MobileInteractionStrongPressed")
  public static let mobileInteractionWeak = ColorAsset(name: "MobileInteractionWeak")
  public static let mobileInteractionWeakDisabled = ColorAsset(name: "MobileInteractionWeakDisabled")
  public static let mobileInteractionWeakPressed = ColorAsset(name: "MobileInteractionWeakPressed")
  public static let mobileInteractionNorm = ColorAsset(name: "MobileInteractionNorm")
  public static let mobileInteractionNormDisabled = ColorAsset(name: "MobileInteractionNormDisabled")
  public static let mobileInteractionNormPressed = ColorAsset(name: "MobileInteractionNormPressed")
  public static let mobileNotificationError = ColorAsset(name: "MobileNotificationError")
  public static let mobileNotificationNorm = ColorAsset(name: "MobileNotificationNorm")
  public static let mobileNotificationSuccess = ColorAsset(name: "MobileNotificationSuccess")
  public static let mobileNotificationWarning = ColorAsset(name: "MobileNotificationWarning")
  public static let mobileSeparatorNorm = ColorAsset(name: "MobileSeparatorNorm")
  public static let mobileShade0 = ColorAsset(name: "MobileShade0")
  public static let mobileShade10 = ColorAsset(name: "MobileShade10")
  public static let mobileShade100 = ColorAsset(name: "MobileShade100")
  public static let mobileShade15 = ColorAsset(name: "MobileShade15")
  public static let mobileShade20 = ColorAsset(name: "MobileShade20")
  public static let mobileShade40 = ColorAsset(name: "MobileShade40")
  public static let mobileShade50 = ColorAsset(name: "MobileShade50")
  public static let mobileShade60 = ColorAsset(name: "MobileShade60")
  public static let mobileShade80 = ColorAsset(name: "MobileShade80")
  public static let mobileSidebarBackground = ColorAsset(name: "MobileSidebarBackground")
  public static let mobileSidebarIconNorm = ColorAsset(name: "MobileSidebarIconNorm")
  public static let mobileSidebarIconWeak = ColorAsset(name: "MobileSidebarIconWeak")
  public static let mobileSidebarInteractionPressed = ColorAsset(name: "MobileSidebarInteractionPressed")
  public static let mobileSidebarInteractionWeakNorm = ColorAsset(name: "MobileSidebarInteractionWeakNorm")
  public static let mobileSidebarInteractionWeakPressed = ColorAsset(name: "MobileSidebarInteractionWeakPressed")
  public static let mobileSidebarSeparator = ColorAsset(name: "MobileSidebarSeparator")
  public static let mobileSidebarTextNorm = ColorAsset(name: "MobileSidebarTextNorm")
  public static let mobileSidebarTextWeak = ColorAsset(name: "MobileSidebarTextWeak")
  public static let mobileTextAccent = ColorAsset(name: "MobileTextAccent")
  public static let mobileTextDisabled = ColorAsset(name: "MobileTextDisabled")
  public static let mobileTextHint = ColorAsset(name: "MobileTextHint")
  public static let mobileTextInverted = ColorAsset(name: "MobileTextInverted")
  public static let mobileTextNorm = ColorAsset(name: "MobileTextNorm")
  public static let mobileTextWeak = ColorAsset(name: "MobileTextWeak")
  public static let protonCarbonBackdropNorm = ColorAsset(name: "ProtonCarbonBackdropNorm")
  public static let protonCarbonBackgroundNorm = ColorAsset(name: "ProtonCarbonBackgroundNorm")
  public static let protonCarbonBackgroundStrong = ColorAsset(name: "ProtonCarbonBackgroundStrong")
  public static let protonCarbonBackgroundWeak = ColorAsset(name: "ProtonCarbonBackgroundWeak")
  public static let protonCarbonBorderNorm = ColorAsset(name: "ProtonCarbonBorderNorm")
  public static let protonCarbonBorderWeak = ColorAsset(name: "ProtonCarbonBorderWeak")
  public static let protonCarbonFieldDisabled = ColorAsset(name: "ProtonCarbonFieldDisabled")
  public static let protonCarbonFieldFocus = ColorAsset(name: "ProtonCarbonFieldFocus")
  public static let protonCarbonFieldHighlight = ColorAsset(name: "ProtonCarbonFieldHighlight")
  public static let protonCarbonFieldHighlightError = ColorAsset(name: "ProtonCarbonFieldHighlightError")
  public static let protonCarbonFieldHover = ColorAsset(name: "ProtonCarbonFieldHover")
  public static let protonCarbonFieldNorm = ColorAsset(name: "ProtonCarbonFieldNorm")
  public static let protonCarbonInteractionDefault = ColorAsset(name: "ProtonCarbonInteractionDefault")
  public static let protonCarbonInteractionDefaultActive = ColorAsset(name: "ProtonCarbonInteractionDefaultActive")
  public static let protonCarbonInteractionDefaultHover = ColorAsset(name: "ProtonCarbonInteractionDefaultHover")
  public static let protonCarbonInteractionNorm = ColorAsset(name: "ProtonCarbonInteractionNorm")
  public static let protonCarbonInteractionNormActive = ColorAsset(name: "ProtonCarbonInteractionNormActive")
  public static let protonCarbonInteractionNormHover = ColorAsset(name: "ProtonCarbonInteractionNormHover")
  public static let protonCarbonInteractionWeak = ColorAsset(name: "ProtonCarbonInteractionWeak")
  public static let protonCarbonInteractionWeakActive = ColorAsset(name: "ProtonCarbonInteractionWeakActive")
  public static let protonCarbonInteractionWeakHover = ColorAsset(name: "ProtonCarbonInteractionWeakHover")
  public static let protonCarbonLinkActive = ColorAsset(name: "ProtonCarbonLinkActive")
  public static let protonCarbonLinkHover = ColorAsset(name: "ProtonCarbonLinkHover")
  public static let protonCarbonLinkNorm = ColorAsset(name: "ProtonCarbonLinkNorm")
  public static let protonCarbonPrimary = ColorAsset(name: "ProtonCarbonPrimary")
  public static let protonCarbonShade0 = ColorAsset(name: "ProtonCarbonShade0")
  public static let protonCarbonShade10 = ColorAsset(name: "ProtonCarbonShade10")
  public static let protonCarbonShade100 = ColorAsset(name: "ProtonCarbonShade100")
  public static let protonCarbonShade20 = ColorAsset(name: "ProtonCarbonShade20")
  public static let protonCarbonShade40 = ColorAsset(name: "ProtonCarbonShade40")
  public static let protonCarbonShade50 = ColorAsset(name: "ProtonCarbonShade50")
  public static let protonCarbonShade60 = ColorAsset(name: "ProtonCarbonShade60")
  public static let protonCarbonShade80 = ColorAsset(name: "ProtonCarbonShade80")
  public static let protonCarbonShadowLifted = ColorAsset(name: "ProtonCarbonShadowLifted")
  public static let protonCarbonShadowNorm = ColorAsset(name: "ProtonCarbonShadowNorm")
  public static let protonCarbonSignalDanger = ColorAsset(name: "ProtonCarbonSignalDanger")
  public static let protonCarbonSignalDangerActive = ColorAsset(name: "ProtonCarbonSignalDangerActive")
  public static let protonCarbonSignalDangerHover = ColorAsset(name: "ProtonCarbonSignalDangerHover")
  public static let protonCarbonSignalInfo = ColorAsset(name: "ProtonCarbonSignalInfo")
  public static let protonCarbonSignalInfoActive = ColorAsset(name: "ProtonCarbonSignalInfoActive")
  public static let protonCarbonSignalInfoHover = ColorAsset(name: "ProtonCarbonSignalInfoHover")
  public static let protonCarbonSignalSuccess = ColorAsset(name: "ProtonCarbonSignalSuccess")
  public static let protonCarbonSignalSuccessActive = ColorAsset(name: "ProtonCarbonSignalSuccessActive")
  public static let protonCarbonSignalSuccessHover = ColorAsset(name: "ProtonCarbonSignalSuccessHover")
  public static let protonCarbonSignalWarning = ColorAsset(name: "ProtonCarbonSignalWarning")
  public static let protonCarbonSignalWarningActive = ColorAsset(name: "ProtonCarbonSignalWarningActive")
  public static let protonCarbonSignalWarningHover = ColorAsset(name: "ProtonCarbonSignalWarningHover")
  public static let protonCarbonTextDisabled = ColorAsset(name: "ProtonCarbonTextDisabled")
  public static let protonCarbonTextHint = ColorAsset(name: "ProtonCarbonTextHint")
  public static let protonCarbonTextInvert = ColorAsset(name: "ProtonCarbonTextInvert")
  public static let protonCarbonTextNorm = ColorAsset(name: "ProtonCarbonTextNorm")
  public static let protonCarbonTextWeak = ColorAsset(name: "ProtonCarbonTextWeak")
  public static let black = ColorAsset(name: "Black")
  public static let cloud = ColorAsset(name: "Cloud")
  public static let ebb = ColorAsset(name: "Ebb")
  public static let white = ColorAsset(name: "White")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

public final class ColorAsset {
  public fileprivate(set) var name: String

  #if os(macOS)
  public typealias Color = NSColor
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  public typealias Color = UIColor
  #endif

  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  public private(set) lazy var color: Color = {
    guard let color = Color(asset: self) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }()

  #if os(iOS) || os(tvOS)
  @available(iOS 11.0, tvOS 11.0, *)
  public func color(compatibleWith traitCollection: UITraitCollection) -> Color {
    let bundle = BundleToken.bundle
    guard let color = Color(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  public private(set) lazy var swiftUIColor: SwiftUI.Color = {
    SwiftUI.Color(asset: self)
  }()
  #endif

  fileprivate init(name: String) {
    self.name = name
  }
}

public extension ColorAsset.Color {
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  convenience init?(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSColor.Name(asset.name), bundle: bundle)
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
public extension SwiftUI.Color {
  init(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }
}
#endif

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
