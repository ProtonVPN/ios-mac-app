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
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal static let blockAds = ImageAsset(name: "BlockAds")
  internal static let checkmarkCircle = ImageAsset(name: "CheckmarkCircle")
  internal static let closeButton = ImageAsset(name: "CloseButton")
  internal static let flatIllustration = ImageAsset(name: "Flat illustration")
  internal static let highSpeedIcon = ImageAsset(name: "HighSpeedIcon")
  internal static let moderateNAT = ImageAsset(name: "ModerateNAT")
  internal static let netshieldIcon = ImageAsset(name: "NetshieldIcon")
  internal static let noLogs = ImageAsset(name: "NoLogs")
  internal static let plusCountries = ImageAsset(name: "PlusCountries")
  internal static let protectFromAttacks = ImageAsset(name: "ProtectFromAttacks")
  internal static let routeSecureServers = ImageAsset(name: "RouteSecureServers")
  internal static let safeModeIOS = ImageAsset(name: "SafeMode-iOS")
  internal static let safeModeMacOS = ImageAsset(name: "SafeMode-macOS")
  internal static let secureCore = ImageAsset(name: "SecureCore")
  internal static let secureCoreDiscourage = ImageAsset(name: "SecureCoreDiscourage")
  internal static let streamingIcon = ImageAsset(name: "StreamingIcon")
  internal static let customisation = ImageAsset(name: "customisation")
  internal static let maximumDeviceLimitUpsell = ImageAsset(name: "maximum-device-limit-upsell")
  internal static let maximumDeviceLimitWarning = ImageAsset(name: "maximum-device-limit-warning")
  internal static let netshieldIOS = ImageAsset(name: "netshield-iOS")
  internal static let netshieldMacOS = ImageAsset(name: "netshield-macOS")
  internal static let profiles = ImageAsset(name: "profiles")
  internal static let speed = ImageAsset(name: "speed")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

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
