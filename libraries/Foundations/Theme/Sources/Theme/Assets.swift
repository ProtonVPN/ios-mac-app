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
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
public typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
public enum Asset {
  public static let wrongCountry = ImageAsset(name: "wrong-country")
  public static let offerBannerGradientLeft = ColorAsset(name: "OfferBannerGradientLeft")
  public static let offerBannerGradientRight = ColorAsset(name: "OfferBannerGradientRight")
  public static let upsellGradientBottom = ColorAsset(name: "UpsellGradientBottom")
  public static let upsellGradientTop = ColorAsset(name: "UpsellGradientTop")
  public static let vpnGreen = ColorAsset(name: "VpnGreen")
  public enum Flags {
    public static let ad = ImageAsset(name: "Flags/AD")
    public static let ae = ImageAsset(name: "Flags/AE")
    public static let af = ImageAsset(name: "Flags/AF")
    public static let ag = ImageAsset(name: "Flags/AG")
    public static let ai = ImageAsset(name: "Flags/AI")
    public static let al = ImageAsset(name: "Flags/AL")
    public static let am = ImageAsset(name: "Flags/AM")
    public static let ao = ImageAsset(name: "Flags/AO")
    public static let ar = ImageAsset(name: "Flags/AR")
    public static let `as` = ImageAsset(name: "Flags/AS")
    public static let at = ImageAsset(name: "Flags/AT")
    public static let au = ImageAsset(name: "Flags/AU")
    public static let aw = ImageAsset(name: "Flags/AW")
    public static let az = ImageAsset(name: "Flags/AZ")
    public static let ba = ImageAsset(name: "Flags/BA")
    public static let bb = ImageAsset(name: "Flags/BB")
    public static let bd = ImageAsset(name: "Flags/BD")
    public static let be = ImageAsset(name: "Flags/BE")
    public static let bf = ImageAsset(name: "Flags/BF")
    public static let bg = ImageAsset(name: "Flags/BG")
    public static let bh = ImageAsset(name: "Flags/BH")
    public static let bi = ImageAsset(name: "Flags/BI")
    public static let bj = ImageAsset(name: "Flags/BJ")
    public static let bl = ImageAsset(name: "Flags/BL")
    public static let bm = ImageAsset(name: "Flags/BM")
    public static let bn = ImageAsset(name: "Flags/BN")
    public static let bo = ImageAsset(name: "Flags/BO")
    public static let bq = ImageAsset(name: "Flags/BQ")
    public static let br = ImageAsset(name: "Flags/BR")
    public static let bs = ImageAsset(name: "Flags/BS")
    public static let bt = ImageAsset(name: "Flags/BT")
    public static let bw = ImageAsset(name: "Flags/BW")
    public static let by = ImageAsset(name: "Flags/BY")
    public static let bz = ImageAsset(name: "Flags/BZ")
    public static let ca = ImageAsset(name: "Flags/CA")
    public static let cd = ImageAsset(name: "Flags/CD")
    public static let cf = ImageAsset(name: "Flags/CF")
    public static let cg = ImageAsset(name: "Flags/CG")
    public static let ch = ImageAsset(name: "Flags/CH")
    public static let ci = ImageAsset(name: "Flags/CI")
    public static let ck = ImageAsset(name: "Flags/CK")
    public static let cl = ImageAsset(name: "Flags/CL")
    public static let cm = ImageAsset(name: "Flags/CM")
    public static let cn = ImageAsset(name: "Flags/CN")
    public static let co = ImageAsset(name: "Flags/CO")
    public static let cr = ImageAsset(name: "Flags/CR")
    public static let cu = ImageAsset(name: "Flags/CU")
    public static let cv = ImageAsset(name: "Flags/CV")
    public static let cw = ImageAsset(name: "Flags/CW")
    public static let cy = ImageAsset(name: "Flags/CY")
    public static let cz = ImageAsset(name: "Flags/CZ")
    public static let de = ImageAsset(name: "Flags/DE")
    public static let dj = ImageAsset(name: "Flags/DJ")
    public static let dk = ImageAsset(name: "Flags/DK")
    public static let dm = ImageAsset(name: "Flags/DM")
    public static let `do` = ImageAsset(name: "Flags/DO")
    public static let dz = ImageAsset(name: "Flags/DZ")
    public static let ec = ImageAsset(name: "Flags/EC")
    public static let ee = ImageAsset(name: "Flags/EE")
    public static let eg = ImageAsset(name: "Flags/EG")
    public static let eh = ImageAsset(name: "Flags/EH")
    public static let er = ImageAsset(name: "Flags/ER")
    public static let es = ImageAsset(name: "Flags/ES")
    public static let et = ImageAsset(name: "Flags/ET")
    public static let fi = ImageAsset(name: "Flags/FI")
    public static let fj = ImageAsset(name: "Flags/FJ")
    public static let fk = ImageAsset(name: "Flags/FK")
    public static let fm = ImageAsset(name: "Flags/FM")
    public static let fo = ImageAsset(name: "Flags/FO")
    public static let fr = ImageAsset(name: "Flags/FR")
    public static let fastest = ImageAsset(name: "Flags/Fastest")
    public static let ga = ImageAsset(name: "Flags/GA")
    public static let gb = ImageAsset(name: "Flags/GB")
    public static let gd = ImageAsset(name: "Flags/GD")
    public static let ge = ImageAsset(name: "Flags/GE")
    public static let gf = ImageAsset(name: "Flags/GF")
    public static let gg = ImageAsset(name: "Flags/GG")
    public static let gh = ImageAsset(name: "Flags/GH")
    public static let gi = ImageAsset(name: "Flags/GI")
    public static let gl = ImageAsset(name: "Flags/GL")
    public static let gm = ImageAsset(name: "Flags/GM")
    public static let gn = ImageAsset(name: "Flags/GN")
    public static let gp = ImageAsset(name: "Flags/GP")
    public static let gq = ImageAsset(name: "Flags/GQ")
    public static let gr = ImageAsset(name: "Flags/GR")
    public static let gt = ImageAsset(name: "Flags/GT")
    public static let gu = ImageAsset(name: "Flags/GU")
    public static let gw = ImageAsset(name: "Flags/GW")
    public static let gy = ImageAsset(name: "Flags/GY")
    public static let hk = ImageAsset(name: "Flags/HK")
    public static let hn = ImageAsset(name: "Flags/HN")
    public static let hr = ImageAsset(name: "Flags/HR")
    public static let ht = ImageAsset(name: "Flags/HT")
    public static let hu = ImageAsset(name: "Flags/HU")
    public static let id = ImageAsset(name: "Flags/ID")
    public static let ie = ImageAsset(name: "Flags/IE")
    public static let il = ImageAsset(name: "Flags/IL")
    public static let im = ImageAsset(name: "Flags/IM")
    public static let `in` = ImageAsset(name: "Flags/IN")
    public static let io = ImageAsset(name: "Flags/IO")
    public static let iq = ImageAsset(name: "Flags/IQ")
    public static let ir = ImageAsset(name: "Flags/IR")
    public static let `is` = ImageAsset(name: "Flags/IS")
    public static let it = ImageAsset(name: "Flags/IT")
    public static let je = ImageAsset(name: "Flags/JE")
    public static let jm = ImageAsset(name: "Flags/JM")
    public static let jo = ImageAsset(name: "Flags/JO")
    public static let jp = ImageAsset(name: "Flags/JP")
    public static let ke = ImageAsset(name: "Flags/KE")
    public static let kg = ImageAsset(name: "Flags/KG")
    public static let kh = ImageAsset(name: "Flags/KH")
    public static let ki = ImageAsset(name: "Flags/KI")
    public static let km = ImageAsset(name: "Flags/KM")
    public static let kn = ImageAsset(name: "Flags/KN")
    public static let kp = ImageAsset(name: "Flags/KP")
    public static let kr = ImageAsset(name: "Flags/KR")
    public static let kw = ImageAsset(name: "Flags/KW")
    public static let ky = ImageAsset(name: "Flags/KY")
    public static let kz = ImageAsset(name: "Flags/KZ")
    public static let la = ImageAsset(name: "Flags/LA")
    public static let lb = ImageAsset(name: "Flags/LB")
    public static let lc = ImageAsset(name: "Flags/LC")
    public static let li = ImageAsset(name: "Flags/LI")
    public static let lk = ImageAsset(name: "Flags/LK")
    public static let lr = ImageAsset(name: "Flags/LR")
    public static let ls = ImageAsset(name: "Flags/LS")
    public static let lt = ImageAsset(name: "Flags/LT")
    public static let lu = ImageAsset(name: "Flags/LU")
    public static let lv = ImageAsset(name: "Flags/LV")
    public static let ly = ImageAsset(name: "Flags/LY")
    public static let ma = ImageAsset(name: "Flags/MA")
    public static let mc = ImageAsset(name: "Flags/MC")
    public static let md = ImageAsset(name: "Flags/MD")
    public static let me = ImageAsset(name: "Flags/ME")
    public static let mf = ImageAsset(name: "Flags/MF")
    public static let mg = ImageAsset(name: "Flags/MG")
    public static let mh = ImageAsset(name: "Flags/MH")
    public static let mk = ImageAsset(name: "Flags/MK")
    public static let ml = ImageAsset(name: "Flags/ML")
    public static let mm = ImageAsset(name: "Flags/MM")
    public static let mn = ImageAsset(name: "Flags/MN")
    public static let mo = ImageAsset(name: "Flags/MO")
    public static let mp = ImageAsset(name: "Flags/MP")
    public static let mq = ImageAsset(name: "Flags/MQ")
    public static let mr = ImageAsset(name: "Flags/MR")
    public static let ms = ImageAsset(name: "Flags/MS")
    public static let mt = ImageAsset(name: "Flags/MT")
    public static let mu = ImageAsset(name: "Flags/MU")
    public static let mv = ImageAsset(name: "Flags/MV")
    public static let mw = ImageAsset(name: "Flags/MW")
    public static let mx = ImageAsset(name: "Flags/MX")
    public static let my = ImageAsset(name: "Flags/MY")
    public static let mz = ImageAsset(name: "Flags/MZ")
    public static let na = ImageAsset(name: "Flags/NA")
    public static let nc = ImageAsset(name: "Flags/NC")
    public static let ne = ImageAsset(name: "Flags/NE")
    public static let nf = ImageAsset(name: "Flags/NF")
    public static let ng = ImageAsset(name: "Flags/NG")
    public static let ni = ImageAsset(name: "Flags/NI")
    public static let nl = ImageAsset(name: "Flags/NL")
    public static let no = ImageAsset(name: "Flags/NO")
    public static let np = ImageAsset(name: "Flags/NP")
    public static let nr = ImageAsset(name: "Flags/NR")
    public static let nu = ImageAsset(name: "Flags/NU")
    public static let nz = ImageAsset(name: "Flags/NZ")
    public static let om = ImageAsset(name: "Flags/OM")
    public static let pa = ImageAsset(name: "Flags/PA")
    public static let pe = ImageAsset(name: "Flags/PE")
    public static let pf = ImageAsset(name: "Flags/PF")
    public static let pg = ImageAsset(name: "Flags/PG")
    public static let ph = ImageAsset(name: "Flags/PH")
    public static let pk = ImageAsset(name: "Flags/PK")
    public static let pl = ImageAsset(name: "Flags/PL")
    public static let pm = ImageAsset(name: "Flags/PM")
    public static let pr = ImageAsset(name: "Flags/PR")
    public static let ps = ImageAsset(name: "Flags/PS")
    public static let pt = ImageAsset(name: "Flags/PT")
    public static let pw = ImageAsset(name: "Flags/PW")
    public static let py = ImageAsset(name: "Flags/PY")
    public static let qa = ImageAsset(name: "Flags/QA")
    public static let re = ImageAsset(name: "Flags/RE")
    public static let ro = ImageAsset(name: "Flags/RO")
    public static let rs = ImageAsset(name: "Flags/RS")
    public static let ru = ImageAsset(name: "Flags/RU")
    public static let rw = ImageAsset(name: "Flags/RW")
    public static let sa = ImageAsset(name: "Flags/SA")
    public static let sb = ImageAsset(name: "Flags/SB")
    public static let sc = ImageAsset(name: "Flags/SC")
    public static let sd = ImageAsset(name: "Flags/SD")
    public static let se = ImageAsset(name: "Flags/SE")
    public static let sg = ImageAsset(name: "Flags/SG")
    public static let sh = ImageAsset(name: "Flags/SH")
    public static let si = ImageAsset(name: "Flags/SI")
    public static let sk = ImageAsset(name: "Flags/SK")
    public static let sl = ImageAsset(name: "Flags/SL")
    public static let sm = ImageAsset(name: "Flags/SM")
    public static let sn = ImageAsset(name: "Flags/SN")
    public static let so = ImageAsset(name: "Flags/SO")
    public static let sr = ImageAsset(name: "Flags/SR")
    public static let ss = ImageAsset(name: "Flags/SS")
    public static let st = ImageAsset(name: "Flags/ST")
    public static let sv = ImageAsset(name: "Flags/SV")
    public static let sx = ImageAsset(name: "Flags/SX")
    public static let sy = ImageAsset(name: "Flags/SY")
    public static let sz = ImageAsset(name: "Flags/SZ")
    public static let tc = ImageAsset(name: "Flags/TC")
    public static let td = ImageAsset(name: "Flags/TD")
    public static let tg = ImageAsset(name: "Flags/TG")
    public static let th = ImageAsset(name: "Flags/TH")
    public static let tj = ImageAsset(name: "Flags/TJ")
    public static let tk = ImageAsset(name: "Flags/TK")
    public static let tl = ImageAsset(name: "Flags/TL")
    public static let tm = ImageAsset(name: "Flags/TM")
    public static let tn = ImageAsset(name: "Flags/TN")
    public static let to = ImageAsset(name: "Flags/TO")
    public static let tr = ImageAsset(name: "Flags/TR")
    public static let tt = ImageAsset(name: "Flags/TT")
    public static let tv = ImageAsset(name: "Flags/TV")
    public static let tw = ImageAsset(name: "Flags/TW")
    public static let tz = ImageAsset(name: "Flags/TZ")
    public static let ua = ImageAsset(name: "Flags/UA")
    public static let ug = ImageAsset(name: "Flags/UG")
    public static let us = ImageAsset(name: "Flags/US")
    public static let uy = ImageAsset(name: "Flags/UY")
    public static let uz = ImageAsset(name: "Flags/UZ")
    public static let va = ImageAsset(name: "Flags/VA")
    public static let vc = ImageAsset(name: "Flags/VC")
    public static let ve = ImageAsset(name: "Flags/VE")
    public static let vg = ImageAsset(name: "Flags/VG")
    public static let vi = ImageAsset(name: "Flags/VI")
    public static let vn = ImageAsset(name: "Flags/VN")
    public static let vu = ImageAsset(name: "Flags/VU")
    public static let wf = ImageAsset(name: "Flags/WF")
    public static let ws = ImageAsset(name: "Flags/WS")
    public static let xk = ImageAsset(name: "Flags/XK")
    public static let ye = ImageAsset(name: "Flags/YE")
    public static let yt = ImageAsset(name: "Flags/YT")
    public static let za = ImageAsset(name: "Flags/ZA")
    public static let zm = ImageAsset(name: "Flags/ZM")
    public static let zw = ImageAsset(name: "Flags/ZW")
  }
  public static let dismissButton = ImageAsset(name: "Dismiss button")
  public static let icAlertProAccount = ImageAsset(name: "ic-alert-pro-account")
  public static let icKillswitch = ImageAsset(name: "ic-killswitch")
  public static let icNetshield = ImageAsset(name: "ic-netshield")
  public static let icVpnBusinessBadge = ImageAsset(name: "ic-vpn-business-badge")
  public static let icsBrandTor = SymbolAsset(name: "ics-brand-tor")
  public static let vpnSubscriptionBadgeHover = ImageAsset(name: "vpn-subscription-badge-hover")
  public static let vpnSubscriptionBadge = ImageAsset(name: "vpn-subscription-badge")
  public static let dynamicAppIconConnected = ImageAsset(name: "DynamicAppIconConnected")
  public static let dynamicAppIconDebugConnected = ImageAsset(name: "DynamicAppIconDebugConnected")
  public static let dynamicAppIconDebugDisconnected = ImageAsset(name: "DynamicAppIconDebugDisconnected")
  public static let dynamicAppIconDisconnected = ImageAsset(name: "DynamicAppIconDisconnected")
  public static let vpnResultConnected = ImageAsset(name: "vpn-result-connected")
  public static let vpnResultNotConnected = ImageAsset(name: "vpn-result-not-connected")
  public static let vpnResultWarning = ImageAsset(name: "vpn-result-warning")
  public static let vpnWordmarkAlwaysDark = ImageAsset(name: "vpn-wordmark-always-dark")
  public static let connected = ImageAsset(name: "connected")
  public static let disconnected = ImageAsset(name: "disconnected")
  public static let emptyIcon = ImageAsset(name: "empty_icon")
  public static let idle = ImageAsset(name: "idle")
  public static let welcomeToProtonVpn = ImageAsset(name: "welcome-to-proton-vpn")
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

public struct ImageAsset {
  public fileprivate(set) var name: String

  #if os(macOS)
  public typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  public typealias Image = UIImage
  #endif

  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
  public var image: Image {
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
  public func image(compatibleWith traitCollection: UITraitCollection) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  public var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

public extension ImageAsset.Image {
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
public extension SwiftUI.Image {
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

public struct SymbolAsset {
  public fileprivate(set) var name: String

  #if os(iOS) || os(tvOS) || os(watchOS)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  public typealias Configuration = UIImage.SymbolConfiguration
  public typealias Image = UIImage

  @available(iOS 12.0, tvOS 12.0, watchOS 5.0, *)
  public var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load symbol asset named \(name).")
    }
    return result
  }

  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  public func image(with configuration: Configuration) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, with: configuration) else {
      fatalError("Unable to load symbol asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  public var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
public extension SwiftUI.Image {
  init(asset: SymbolAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: SymbolAsset, label: Text) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: SymbolAsset) {
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
