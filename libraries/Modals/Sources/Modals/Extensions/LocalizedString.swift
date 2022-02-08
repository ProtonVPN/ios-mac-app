// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// Plural format key: "FREE subscription offers %#@num_servers@ in %#@num_countries@"
  public static func onboardingEstablishSubtitle(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "onboarding_establish_subtitle", p1, p2)
  }
  /// Get Plus
  public static var onboardingGetPlus: String { return LocalizedString.tr("Localizable", "onboarding_get_plus") }
  /// Plural format key: "%#@VARIABLE@"
  public static func onboardingPurchasedSubtitle(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "onboarding_purchased_subtitle", p1)
  }
  /// Built-in adblocker (NetShield)
  public static var onboardingUpsellFeatureHighSpeed: String { return LocalizedString.tr("Localizable", "onboarding_upsell_feature_highSpeed") }
  /// Plural format key: "%#@VARIABLE@"
  public static func onboardingUpsellFeatureMultipleDevices(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "onboarding_upsell_feature_multipleDevices", p1)
  }
  /// Highest speed (10 Gbps)
  public static var onboardingUpsellFeatureNetshield: String { return LocalizedString.tr("Localizable", "onboarding_upsell_feature_netshield") }
  /// Access streaming services globally
  public static var onboardingUpsellFeatureStreaming: String { return LocalizedString.tr("Localizable", "onboarding_upsell_feature_streaming") }
  /// and more premium features...
  public static var onboardingUpsellFeaturesFooter: String { return LocalizedString.tr("Localizable", "onboarding_upsell_features_footer") }
  /// Use limited FREE plan
  public static var onboardingUpsellStayFree: String { return LocalizedString.tr("Localizable", "onboarding_upsell_stay_free") }
  /// Plural format key: "Access all %#@num_servers@ in %#@num_countries@ with Plus"
  public static func onboardingUpsellTitle(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "onboarding_upsell_title", p1, p2)
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
