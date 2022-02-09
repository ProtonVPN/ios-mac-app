// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// Plural format key: "FREE subscription offers %#@num_servers@ in %#@num_countries@"
  public static func modalsEstablishSubtitle(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "modals_establish_subtitle", p1, p2)
  }
  /// Get Plus
  public static var modalsGetPlus: String { return LocalizedString.tr("Localizable", "modals_get_plus") }
  /// Plural format key: "%#@VARIABLE@"
  public static func modalsPurchasedSubtitle(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "modals_purchased_subtitle", p1)
  }
  /// Built-in adblocker (NetShield)
  public static var modalsUpsellFeatureHighSpeed: String { return LocalizedString.tr("Localizable", "modals_upsell_feature_highSpeed") }
  /// Plural format key: "%#@VARIABLE@"
  public static func modalsUpsellFeatureMultipleDevices(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "modals_upsell_feature_multipleDevices", p1)
  }
  /// Highest speed (10 Gbps)
  public static var modalsUpsellFeatureNetshield: String { return LocalizedString.tr("Localizable", "modals_upsell_feature_netshield") }
  /// Access streaming services globally
  public static var modalsUpsellFeatureStreaming: String { return LocalizedString.tr("Localizable", "modals_upsell_feature_streaming") }
  /// and more premium features...
  public static var modalsUpsellFeaturesFooter: String { return LocalizedString.tr("Localizable", "modals_upsell_features_footer") }
  /// Use limited FREE plan
  public static var modalsUpsellStayFree: String { return LocalizedString.tr("Localizable", "modals_upsell_stay_free") }
  /// Plural format key: "Access all %#@num_servers@ in %#@num_countries@ with Plus"
  public static func modalsUpsellTitle(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "modals_upsell_title", p1, p2)
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension LocalizedString {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = localizeStringAndFallbackToEn(key, table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
