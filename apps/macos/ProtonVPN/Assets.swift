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
typealias AssetColorTypeAlias = ColorAsset.Color
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
enum Asset {
    static let accentColor = ColorAsset(name: "AccentColor")
    static let sessionsLimit = ImageAsset(name: "sessions_limit")
    static let adLarge = ImageAsset(name: "ad-large")
    static let aeLarge = ImageAsset(name: "ae-large")
    static let afLarge = ImageAsset(name: "af-large")
    static let agLarge = ImageAsset(name: "ag-large")
    static let alLarge = ImageAsset(name: "al-large")
    static let amLarge = ImageAsset(name: "am-large")
    static let aoLarge = ImageAsset(name: "ao-large")
    static let arLarge = ImageAsset(name: "ar-large")
    static let atLarge = ImageAsset(name: "at-large")
    static let auLarge = ImageAsset(name: "au-large")
    static let azLarge = ImageAsset(name: "az-large")
    static let baLarge = ImageAsset(name: "ba-large")
    static let bbLarge = ImageAsset(name: "bb-large")
    static let bdLarge = ImageAsset(name: "bd-large")
    static let beLarge = ImageAsset(name: "be-large")
    static let bfLarge = ImageAsset(name: "bf-large")
    static let bgLarge = ImageAsset(name: "bg-large")
    static let bhLarge = ImageAsset(name: "bh-large")
    static let biLarge = ImageAsset(name: "bi-large")
    static let bjLarge = ImageAsset(name: "bj-large")
    static let bnLarge = ImageAsset(name: "bn-large")
    static let boLarge = ImageAsset(name: "bo-large")
    static let brLarge = ImageAsset(name: "br-large")
    static let bsLarge = ImageAsset(name: "bs-large")
    static let btLarge = ImageAsset(name: "bt-large")
    static let bwLarge = ImageAsset(name: "bw-large")
    static let byLarge = ImageAsset(name: "by-large")
    static let bzLarge = ImageAsset(name: "bz-large")
    static let caLarge = ImageAsset(name: "ca-large")
    static let cdLarge = ImageAsset(name: "cd-large")
    static let cfLarge = ImageAsset(name: "cf-large")
    static let cgLarge = ImageAsset(name: "cg-large")
    static let chLarge = ImageAsset(name: "ch-large")
    static let ciLarge = ImageAsset(name: "ci-large")
    static let ckLarge = ImageAsset(name: "ck-large")
    static let clLarge = ImageAsset(name: "cl-large")
    static let cmLarge = ImageAsset(name: "cm-large")
    static let cnLarge = ImageAsset(name: "cn-large")
    static let coLarge = ImageAsset(name: "co-large")
    static let crLarge = ImageAsset(name: "cr-large")
    static let cuLarge = ImageAsset(name: "cu-large")
    static let cvLarge = ImageAsset(name: "cv-large")
    static let cyLarge = ImageAsset(name: "cy-large")
    static let czLarge = ImageAsset(name: "cz-large")
    static let deLarge = ImageAsset(name: "de-large")
    static let djLarge = ImageAsset(name: "dj-large")
    static let dkLarge = ImageAsset(name: "dk-large")
    static let dmLarge = ImageAsset(name: "dm-large")
    static let doLarge = ImageAsset(name: "do-large")
    static let dzLarge = ImageAsset(name: "dz-large")
    static let ecLarge = ImageAsset(name: "ec-large")
    static let eeLarge = ImageAsset(name: "ee-large")
    static let egLarge = ImageAsset(name: "eg-large")
    static let ehLarge = ImageAsset(name: "eh-large")
    static let erLarge = ImageAsset(name: "er-large")
    static let esLarge = ImageAsset(name: "es-large")
    static let etLarge = ImageAsset(name: "et-large")
    static let fiLarge = ImageAsset(name: "fi-large")
    static let fjLarge = ImageAsset(name: "fj-large")
    static let fmLarge = ImageAsset(name: "fm-large")
    static let frLarge = ImageAsset(name: "fr-large")
    static let gaLarge = ImageAsset(name: "ga-large")
    static let gbLarge = ImageAsset(name: "gb-large")
    static let gdLarge = ImageAsset(name: "gd-large")
    static let geLarge = ImageAsset(name: "ge-large")
    static let ghLarge = ImageAsset(name: "gh-large")
    static let gmLarge = ImageAsset(name: "gm-large")
    static let gnLarge = ImageAsset(name: "gn-large")
    static let gqLarge = ImageAsset(name: "gq-large")
    static let grLarge = ImageAsset(name: "gr-large")
    static let gtLarge = ImageAsset(name: "gt-large")
    static let gwLarge = ImageAsset(name: "gw-large")
    static let gyLarge = ImageAsset(name: "gy-large")
    static let hkLarge = ImageAsset(name: "hk-large")
    static let hnLarge = ImageAsset(name: "hn-large")
    static let hrLarge = ImageAsset(name: "hr-large")
    static let htLarge = ImageAsset(name: "ht-large")
    static let huLarge = ImageAsset(name: "hu-large")
    static let idLarge = ImageAsset(name: "id-large")
    static let ieLarge = ImageAsset(name: "ie-large")
    static let ilLarge = ImageAsset(name: "il-large")
    static let inLarge = ImageAsset(name: "in-large")
    static let iqLarge = ImageAsset(name: "iq-large")
    static let irLarge = ImageAsset(name: "ir-large")
    static let isLarge = ImageAsset(name: "is-large")
    static let itLarge = ImageAsset(name: "it-large")
    static let jmLarge = ImageAsset(name: "jm-large")
    static let joLarge = ImageAsset(name: "jo-large")
    static let jpLarge = ImageAsset(name: "jp-large")
    static let keLarge = ImageAsset(name: "ke-large")
    static let kgLarge = ImageAsset(name: "kg-large")
    static let khLarge = ImageAsset(name: "kh-large")
    static let kiLarge = ImageAsset(name: "ki-large")
    static let kmLarge = ImageAsset(name: "km-large")
    static let knLarge = ImageAsset(name: "kn-large")
    static let kpLarge = ImageAsset(name: "kp-large")
    static let krLarge = ImageAsset(name: "kr-large")
    static let kwLarge = ImageAsset(name: "kw-large")
    static let kzLarge = ImageAsset(name: "kz-large")
    static let laLarge = ImageAsset(name: "la-large")
    static let lbLarge = ImageAsset(name: "lb-large")
    static let lcLarge = ImageAsset(name: "lc-large")
    static let liLarge = ImageAsset(name: "li-large")
    static let lkLarge = ImageAsset(name: "lk-large")
    static let lrLarge = ImageAsset(name: "lr-large")
    static let lsLarge = ImageAsset(name: "ls-large")
    static let ltLarge = ImageAsset(name: "lt-large")
    static let luLarge = ImageAsset(name: "lu-large")
    static let lvLarge = ImageAsset(name: "lv-large")
    static let lyLarge = ImageAsset(name: "ly-large")
    static let maLarge = ImageAsset(name: "ma-large")
    static let mcLarge = ImageAsset(name: "mc-large")
    static let mdLarge = ImageAsset(name: "md-large")
    static let meLarge = ImageAsset(name: "me-large")
    static let mgLarge = ImageAsset(name: "mg-large")
    static let mhLarge = ImageAsset(name: "mh-large")
    static let mkLarge = ImageAsset(name: "mk-large")
    static let mlLarge = ImageAsset(name: "ml-large")
    static let mmLarge = ImageAsset(name: "mm-large")
    static let mnLarge = ImageAsset(name: "mn-large")
    static let mrLarge = ImageAsset(name: "mr-large")
    static let mtLarge = ImageAsset(name: "mt-large")
    static let muLarge = ImageAsset(name: "mu-large")
    static let mvLarge = ImageAsset(name: "mv-large")
    static let mwLarge = ImageAsset(name: "mw-large")
    static let mxLarge = ImageAsset(name: "mx-large")
    static let myLarge = ImageAsset(name: "my-large")
    static let mzLarge = ImageAsset(name: "mz-large")
    static let naLarge = ImageAsset(name: "na-large")
    static let neLarge = ImageAsset(name: "ne-large")
    static let ngLarge = ImageAsset(name: "ng-large")
    static let niLarge = ImageAsset(name: "ni-large")
    static let nlLarge = ImageAsset(name: "nl-large")
    static let noLarge = ImageAsset(name: "no-large")
    static let npLarge = ImageAsset(name: "np-large")
    static let nrLarge = ImageAsset(name: "nr-large")
    static let nuLarge = ImageAsset(name: "nu-large")
    static let nzLarge = ImageAsset(name: "nz-large")
    static let omLarge = ImageAsset(name: "om-large")
    static let paLarge = ImageAsset(name: "pa-large")
    static let peLarge = ImageAsset(name: "pe-large")
    static let pgLarge = ImageAsset(name: "pg-large")
    static let phLarge = ImageAsset(name: "ph-large")
    static let pkLarge = ImageAsset(name: "pk-large")
    static let plLarge = ImageAsset(name: "pl-large")
    static let prLarge = ImageAsset(name: "pr-large")
    static let psLarge = ImageAsset(name: "ps-large")
    static let ptLarge = ImageAsset(name: "pt-large")
    static let pwLarge = ImageAsset(name: "pw-large")
    static let pyLarge = ImageAsset(name: "py-large")
    static let qaLarge = ImageAsset(name: "qa-large")
    static let roLarge = ImageAsset(name: "ro-large")
    static let rsLarge = ImageAsset(name: "rs-large")
    static let ruLarge = ImageAsset(name: "ru-large")
    static let rwLarge = ImageAsset(name: "rw-large")
    static let saLarge = ImageAsset(name: "sa-large")
    static let sbLarge = ImageAsset(name: "sb-large")
    static let scLarge = ImageAsset(name: "sc-large")
    static let sdLarge = ImageAsset(name: "sd-large")
    static let seLarge = ImageAsset(name: "se-large")
    static let sgLarge = ImageAsset(name: "sg-large")
    static let siLarge = ImageAsset(name: "si-large")
    static let skLarge = ImageAsset(name: "sk-large")
    static let slLarge = ImageAsset(name: "sl-large")
    static let smLarge = ImageAsset(name: "sm-large")
    static let snLarge = ImageAsset(name: "sn-large")
    static let soLarge = ImageAsset(name: "so-large")
    static let srLarge = ImageAsset(name: "sr-large")
    static let ssLarge = ImageAsset(name: "ss-large")
    static let stLarge = ImageAsset(name: "st-large")
    static let svLarge = ImageAsset(name: "sv-large")
    static let syLarge = ImageAsset(name: "sy-large")
    static let szLarge = ImageAsset(name: "sz-large")
    static let tdLarge = ImageAsset(name: "td-large")
    static let tgLarge = ImageAsset(name: "tg-large")
    static let thLarge = ImageAsset(name: "th-large")
    static let tjLarge = ImageAsset(name: "tj-large")
    static let tlLarge = ImageAsset(name: "tl-large")
    static let tmLarge = ImageAsset(name: "tm-large")
    static let tnLarge = ImageAsset(name: "tn-large")
    static let toLarge = ImageAsset(name: "to-large")
    static let trLarge = ImageAsset(name: "tr-large")
    static let ttLarge = ImageAsset(name: "tt-large")
    static let tvLarge = ImageAsset(name: "tv-large")
    static let twLarge = ImageAsset(name: "tw-large")
    static let tzLarge = ImageAsset(name: "tz-large")
    static let uaLarge = ImageAsset(name: "ua-large")
    static let ugLarge = ImageAsset(name: "ug-large")
    static let ukLarge = ImageAsset(name: "uk-large")
    static let usLarge = ImageAsset(name: "us-large")
    static let uyLarge = ImageAsset(name: "uy-large")
    static let uzLarge = ImageAsset(name: "uz-large")
    static let vaLarge = ImageAsset(name: "va-large")
    static let vcLarge = ImageAsset(name: "vc-large")
    static let veLarge = ImageAsset(name: "ve-large")
    static let vnLarge = ImageAsset(name: "vn-large")
    static let vuLarge = ImageAsset(name: "vu-large")
    static let wsLarge = ImageAsset(name: "ws-large")
    static let xkLarge = ImageAsset(name: "xk-large")
    static let yeLarge = ImageAsset(name: "ye-large")
    static let zaLarge = ImageAsset(name: "za-large")
    static let zmLarge = ImageAsset(name: "zm-large")
    static let zwLarge = ImageAsset(name: "zw-large")
    static let ksSwift5Helper = ImageAsset(name: "ks_swift5_helper")
    static let neagent = ImageAsset(name: "neagent")
    static let neagentIndicator1 = ImageAsset(name: "neagent_indicator_1")
    static let neagentIndicator2 = ImageAsset(name: "neagent_indicator_2")
    static let hermesDragIcon = ImageAsset(name: "hermesDragIcon")
    static let hermesSplashScreen = ImageAsset(name: "hermesSplashScreen")
    static let qsDetailTriangle = ImageAsset(name: "qs_detail_triangle")
    static let worldMap = ImageAsset(name: "world-map")
}

// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

final class ColorAsset {
    fileprivate(set) var name: String

    #if os(macOS)
        typealias Color = NSColor
    #elseif os(iOS) || os(tvOS) || os(watchOS)
        typealias Color = UIColor
    #endif

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
    private(set) lazy var color: Color = {
        guard let color = Color(asset: self) else {
            fatalError("Unable to load color asset named \(name).")
        }
        return color
    }()

    #if os(iOS) || os(tvOS)
        @available(iOS 11.0, tvOS 11.0, *)
        func color(compatibleWith traitCollection: UITraitCollection) -> Color {
            let bundle = BundleToken.bundle
            guard let color = Color(named: name, in: bundle, compatibleWith: traitCollection) else {
                fatalError("Unable to load color asset named \(name).")
            }
            return color
        }
    #endif

    #if canImport(SwiftUI)
        @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
        private(set) lazy var swiftUIColor: SwiftUI.Color = .init(asset: self)
    #endif

    fileprivate init(name: String) {
        self.name = name
    }
}

extension ColorAsset.Color {
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
    extension SwiftUI.Color {
        init(asset: ColorAsset) {
            let bundle = BundleToken.bundle
            self.init(asset.name, bundle: bundle)
        }
    }
#endif

struct ImageAsset {
    fileprivate(set) var name: String

    #if os(macOS)
        typealias Image = NSImage
    #elseif os(iOS) || os(tvOS) || os(watchOS)
        typealias Image = UIImage
    #endif

    @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
    var image: Image {
        let bundle = BundleToken.bundle
        #if os(iOS) || os(tvOS)
            let image = Image(named: name, in: bundle, compatibleWith: nil)
        #elseif os(macOS)
            let name = NSImage.Name(name)
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
        func image(compatibleWith traitCollection: UITraitCollection) -> Image {
            let bundle = BundleToken.bundle
            guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
                fatalError("Unable to load image asset named \(name).")
            }
            return result
        }
    #endif

    #if canImport(SwiftUI)
        @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
        var swiftUIImage: SwiftUI.Image {
            SwiftUI.Image(asset: self)
        }
    #endif
}

extension ImageAsset.Image {
    @available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
    @available(
        macOS,
        deprecated,
        message: "This initializer is unsafe on macOS, please use the ImageAsset.image property"
    )
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
    extension SwiftUI.Image {
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
