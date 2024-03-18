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
internal typealias AssetColorTypeAlias = ColorAsset.Color
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal static let accentColor = ColorAsset(name: "AccentColor")
  internal static let sessionsLimit = ImageAsset(name: "sessions_limit")
  internal static let adLarge = ImageAsset(name: "ad-large")
  internal static let aeLarge = ImageAsset(name: "ae-large")
  internal static let afLarge = ImageAsset(name: "af-large")
  internal static let agLarge = ImageAsset(name: "ag-large")
  internal static let alLarge = ImageAsset(name: "al-large")
  internal static let amLarge = ImageAsset(name: "am-large")
  internal static let aoLarge = ImageAsset(name: "ao-large")
  internal static let arLarge = ImageAsset(name: "ar-large")
  internal static let atLarge = ImageAsset(name: "at-large")
  internal static let auLarge = ImageAsset(name: "au-large")
  internal static let azLarge = ImageAsset(name: "az-large")
  internal static let baLarge = ImageAsset(name: "ba-large")
  internal static let bbLarge = ImageAsset(name: "bb-large")
  internal static let bdLarge = ImageAsset(name: "bd-large")
  internal static let beLarge = ImageAsset(name: "be-large")
  internal static let bfLarge = ImageAsset(name: "bf-large")
  internal static let bgLarge = ImageAsset(name: "bg-large")
  internal static let bhLarge = ImageAsset(name: "bh-large")
  internal static let biLarge = ImageAsset(name: "bi-large")
  internal static let bjLarge = ImageAsset(name: "bj-large")
  internal static let bnLarge = ImageAsset(name: "bn-large")
  internal static let boLarge = ImageAsset(name: "bo-large")
  internal static let brLarge = ImageAsset(name: "br-large")
  internal static let bsLarge = ImageAsset(name: "bs-large")
  internal static let btLarge = ImageAsset(name: "bt-large")
  internal static let bwLarge = ImageAsset(name: "bw-large")
  internal static let byLarge = ImageAsset(name: "by-large")
  internal static let bzLarge = ImageAsset(name: "bz-large")
  internal static let caLarge = ImageAsset(name: "ca-large")
  internal static let cdLarge = ImageAsset(name: "cd-large")
  internal static let cfLarge = ImageAsset(name: "cf-large")
  internal static let cgLarge = ImageAsset(name: "cg-large")
  internal static let chLarge = ImageAsset(name: "ch-large")
  internal static let ciLarge = ImageAsset(name: "ci-large")
  internal static let ckLarge = ImageAsset(name: "ck-large")
  internal static let clLarge = ImageAsset(name: "cl-large")
  internal static let cmLarge = ImageAsset(name: "cm-large")
  internal static let cnLarge = ImageAsset(name: "cn-large")
  internal static let coLarge = ImageAsset(name: "co-large")
  internal static let crLarge = ImageAsset(name: "cr-large")
  internal static let cuLarge = ImageAsset(name: "cu-large")
  internal static let cvLarge = ImageAsset(name: "cv-large")
  internal static let cyLarge = ImageAsset(name: "cy-large")
  internal static let czLarge = ImageAsset(name: "cz-large")
  internal static let deLarge = ImageAsset(name: "de-large")
  internal static let djLarge = ImageAsset(name: "dj-large")
  internal static let dkLarge = ImageAsset(name: "dk-large")
  internal static let dmLarge = ImageAsset(name: "dm-large")
  internal static let doLarge = ImageAsset(name: "do-large")
  internal static let dzLarge = ImageAsset(name: "dz-large")
  internal static let ecLarge = ImageAsset(name: "ec-large")
  internal static let eeLarge = ImageAsset(name: "ee-large")
  internal static let egLarge = ImageAsset(name: "eg-large")
  internal static let ehLarge = ImageAsset(name: "eh-large")
  internal static let erLarge = ImageAsset(name: "er-large")
  internal static let esLarge = ImageAsset(name: "es-large")
  internal static let etLarge = ImageAsset(name: "et-large")
  internal static let fiLarge = ImageAsset(name: "fi-large")
  internal static let fjLarge = ImageAsset(name: "fj-large")
  internal static let fmLarge = ImageAsset(name: "fm-large")
  internal static let frLarge = ImageAsset(name: "fr-large")
  internal static let gaLarge = ImageAsset(name: "ga-large")
  internal static let gbLarge = ImageAsset(name: "gb-large")
  internal static let gdLarge = ImageAsset(name: "gd-large")
  internal static let geLarge = ImageAsset(name: "ge-large")
  internal static let ghLarge = ImageAsset(name: "gh-large")
  internal static let gmLarge = ImageAsset(name: "gm-large")
  internal static let gnLarge = ImageAsset(name: "gn-large")
  internal static let gqLarge = ImageAsset(name: "gq-large")
  internal static let grLarge = ImageAsset(name: "gr-large")
  internal static let gtLarge = ImageAsset(name: "gt-large")
  internal static let gwLarge = ImageAsset(name: "gw-large")
  internal static let gyLarge = ImageAsset(name: "gy-large")
  internal static let hkLarge = ImageAsset(name: "hk-large")
  internal static let hnLarge = ImageAsset(name: "hn-large")
  internal static let hrLarge = ImageAsset(name: "hr-large")
  internal static let htLarge = ImageAsset(name: "ht-large")
  internal static let huLarge = ImageAsset(name: "hu-large")
  internal static let idLarge = ImageAsset(name: "id-large")
  internal static let ieLarge = ImageAsset(name: "ie-large")
  internal static let ilLarge = ImageAsset(name: "il-large")
  internal static let inLarge = ImageAsset(name: "in-large")
  internal static let iqLarge = ImageAsset(name: "iq-large")
  internal static let irLarge = ImageAsset(name: "ir-large")
  internal static let isLarge = ImageAsset(name: "is-large")
  internal static let itLarge = ImageAsset(name: "it-large")
  internal static let jmLarge = ImageAsset(name: "jm-large")
  internal static let joLarge = ImageAsset(name: "jo-large")
  internal static let jpLarge = ImageAsset(name: "jp-large")
  internal static let keLarge = ImageAsset(name: "ke-large")
  internal static let kgLarge = ImageAsset(name: "kg-large")
  internal static let khLarge = ImageAsset(name: "kh-large")
  internal static let kiLarge = ImageAsset(name: "ki-large")
  internal static let kmLarge = ImageAsset(name: "km-large")
  internal static let knLarge = ImageAsset(name: "kn-large")
  internal static let kpLarge = ImageAsset(name: "kp-large")
  internal static let krLarge = ImageAsset(name: "kr-large")
  internal static let kwLarge = ImageAsset(name: "kw-large")
  internal static let kzLarge = ImageAsset(name: "kz-large")
  internal static let laLarge = ImageAsset(name: "la-large")
  internal static let lbLarge = ImageAsset(name: "lb-large")
  internal static let lcLarge = ImageAsset(name: "lc-large")
  internal static let liLarge = ImageAsset(name: "li-large")
  internal static let lkLarge = ImageAsset(name: "lk-large")
  internal static let lrLarge = ImageAsset(name: "lr-large")
  internal static let lsLarge = ImageAsset(name: "ls-large")
  internal static let ltLarge = ImageAsset(name: "lt-large")
  internal static let luLarge = ImageAsset(name: "lu-large")
  internal static let lvLarge = ImageAsset(name: "lv-large")
  internal static let lyLarge = ImageAsset(name: "ly-large")
  internal static let maLarge = ImageAsset(name: "ma-large")
  internal static let mcLarge = ImageAsset(name: "mc-large")
  internal static let mdLarge = ImageAsset(name: "md-large")
  internal static let meLarge = ImageAsset(name: "me-large")
  internal static let mgLarge = ImageAsset(name: "mg-large")
  internal static let mhLarge = ImageAsset(name: "mh-large")
  internal static let mkLarge = ImageAsset(name: "mk-large")
  internal static let mlLarge = ImageAsset(name: "ml-large")
  internal static let mmLarge = ImageAsset(name: "mm-large")
  internal static let mnLarge = ImageAsset(name: "mn-large")
  internal static let mrLarge = ImageAsset(name: "mr-large")
  internal static let mtLarge = ImageAsset(name: "mt-large")
  internal static let muLarge = ImageAsset(name: "mu-large")
  internal static let mvLarge = ImageAsset(name: "mv-large")
  internal static let mwLarge = ImageAsset(name: "mw-large")
  internal static let mxLarge = ImageAsset(name: "mx-large")
  internal static let myLarge = ImageAsset(name: "my-large")
  internal static let mzLarge = ImageAsset(name: "mz-large")
  internal static let naLarge = ImageAsset(name: "na-large")
  internal static let neLarge = ImageAsset(name: "ne-large")
  internal static let ngLarge = ImageAsset(name: "ng-large")
  internal static let niLarge = ImageAsset(name: "ni-large")
  internal static let nlLarge = ImageAsset(name: "nl-large")
  internal static let noLarge = ImageAsset(name: "no-large")
  internal static let npLarge = ImageAsset(name: "np-large")
  internal static let nrLarge = ImageAsset(name: "nr-large")
  internal static let nuLarge = ImageAsset(name: "nu-large")
  internal static let nzLarge = ImageAsset(name: "nz-large")
  internal static let omLarge = ImageAsset(name: "om-large")
  internal static let paLarge = ImageAsset(name: "pa-large")
  internal static let peLarge = ImageAsset(name: "pe-large")
  internal static let pgLarge = ImageAsset(name: "pg-large")
  internal static let phLarge = ImageAsset(name: "ph-large")
  internal static let pkLarge = ImageAsset(name: "pk-large")
  internal static let plLarge = ImageAsset(name: "pl-large")
  internal static let prLarge = ImageAsset(name: "pr-large")
  internal static let psLarge = ImageAsset(name: "ps-large")
  internal static let ptLarge = ImageAsset(name: "pt-large")
  internal static let pwLarge = ImageAsset(name: "pw-large")
  internal static let pyLarge = ImageAsset(name: "py-large")
  internal static let qaLarge = ImageAsset(name: "qa-large")
  internal static let roLarge = ImageAsset(name: "ro-large")
  internal static let rsLarge = ImageAsset(name: "rs-large")
  internal static let ruLarge = ImageAsset(name: "ru-large")
  internal static let rwLarge = ImageAsset(name: "rw-large")
  internal static let saLarge = ImageAsset(name: "sa-large")
  internal static let sbLarge = ImageAsset(name: "sb-large")
  internal static let scLarge = ImageAsset(name: "sc-large")
  internal static let sdLarge = ImageAsset(name: "sd-large")
  internal static let seLarge = ImageAsset(name: "se-large")
  internal static let sgLarge = ImageAsset(name: "sg-large")
  internal static let siLarge = ImageAsset(name: "si-large")
  internal static let skLarge = ImageAsset(name: "sk-large")
  internal static let slLarge = ImageAsset(name: "sl-large")
  internal static let smLarge = ImageAsset(name: "sm-large")
  internal static let snLarge = ImageAsset(name: "sn-large")
  internal static let soLarge = ImageAsset(name: "so-large")
  internal static let srLarge = ImageAsset(name: "sr-large")
  internal static let ssLarge = ImageAsset(name: "ss-large")
  internal static let stLarge = ImageAsset(name: "st-large")
  internal static let svLarge = ImageAsset(name: "sv-large")
  internal static let syLarge = ImageAsset(name: "sy-large")
  internal static let szLarge = ImageAsset(name: "sz-large")
  internal static let tdLarge = ImageAsset(name: "td-large")
  internal static let tgLarge = ImageAsset(name: "tg-large")
  internal static let thLarge = ImageAsset(name: "th-large")
  internal static let tjLarge = ImageAsset(name: "tj-large")
  internal static let tlLarge = ImageAsset(name: "tl-large")
  internal static let tmLarge = ImageAsset(name: "tm-large")
  internal static let tnLarge = ImageAsset(name: "tn-large")
  internal static let toLarge = ImageAsset(name: "to-large")
  internal static let trLarge = ImageAsset(name: "tr-large")
  internal static let ttLarge = ImageAsset(name: "tt-large")
  internal static let tvLarge = ImageAsset(name: "tv-large")
  internal static let twLarge = ImageAsset(name: "tw-large")
  internal static let tzLarge = ImageAsset(name: "tz-large")
  internal static let uaLarge = ImageAsset(name: "ua-large")
  internal static let ugLarge = ImageAsset(name: "ug-large")
  internal static let ukLarge = ImageAsset(name: "uk-large")
  internal static let usLarge = ImageAsset(name: "us-large")
  internal static let uyLarge = ImageAsset(name: "uy-large")
  internal static let uzLarge = ImageAsset(name: "uz-large")
  internal static let vaLarge = ImageAsset(name: "va-large")
  internal static let vcLarge = ImageAsset(name: "vc-large")
  internal static let veLarge = ImageAsset(name: "ve-large")
  internal static let vnLarge = ImageAsset(name: "vn-large")
  internal static let vuLarge = ImageAsset(name: "vu-large")
  internal static let wsLarge = ImageAsset(name: "ws-large")
  internal static let xkLarge = ImageAsset(name: "xk-large")
  internal static let yeLarge = ImageAsset(name: "ye-large")
  internal static let zaLarge = ImageAsset(name: "za-large")
  internal static let zmLarge = ImageAsset(name: "zm-large")
  internal static let zwLarge = ImageAsset(name: "zw-large")
  internal static let ksSwift5Helper = ImageAsset(name: "ks_swift5_helper")
  internal static let neagent = ImageAsset(name: "neagent")
  internal static let neagentIndicator1 = ImageAsset(name: "neagent_indicator_1")
  internal static let neagentIndicator2 = ImageAsset(name: "neagent_indicator_2")
  internal static let qsDetailTriangle = ImageAsset(name: "qs_detail_triangle")
  internal static let worldMap = ImageAsset(name: "world-map")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

internal final class ColorAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Color = NSColor
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Color = UIColor
  #endif

  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  internal private(set) lazy var color: Color = {
    guard let color = Color(asset: self) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }()

  #if os(iOS) || os(tvOS)
  @available(iOS 11.0, tvOS 11.0, *)
  internal func color(compatibleWith traitCollection: UITraitCollection) -> Color {
    let bundle = BundleToken.bundle
    guard let color = Color(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal private(set) lazy var swiftUIColor: SwiftUI.Color = {
    SwiftUI.Color(asset: self)
  }()
  #endif

  fileprivate init(name: String) {
    self.name = name
  }
}

internal extension ColorAsset.Color {
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
internal extension SwiftUI.Color {
  init(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }
}
#endif

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Image = UIImage
  #endif

  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
  internal var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let name = NSImage.Name(self.name)
    let image = (bundle == .main) ? NSImage(named: name) : bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if os(iOS) || os(tvOS)
  @available(iOS 8.0, tvOS 9.0, *)
  internal func image(compatibleWith traitCollection: UITraitCollection) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

internal extension ImageAsset.Image {
  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init?(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = BundleToken.bundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Image {
  init(asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: ImageAsset, label: Text) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(decorative: asset.name, bundle: bundle)
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
