// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// Cancel
  public static var modalsCommonCancel: String { return LocalizedString.tr("Localizable", "modals_common_cancel") }
  /// Learn more
  public static var modalsCommonLearnMore: String { return LocalizedString.tr("Localizable", "modals_common_learn_more") }
  /// Activate Secure Core
  public static var modalsDiscourageSecureCoreActivate: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_activate") }
  /// Don’t show again
  public static var modalsDiscourageSecureCoreDontShow: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_dont_show") }
  /// Secure Core offers the highest level of security and privacy, but it may reduce your internet speed. If you need more performance, you can disable Secure Core.
  public static var modalsDiscourageSecureCoreSubtitle: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_subtitle") }
  /// A note about speed...
  public static var modalsDiscourageSecureCoreTitle: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_title") }
  /// Upgrade
  public static var modalsGetPlus: String { return LocalizedString.tr("Localizable", "modals_get_plus") }
  /// Browse at the highest speeds (10 Gbps)
  public static var modalsUpsellAllCountriesFeatureHighSpeed: String { return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_highSpeed") }
  /// Plural format key: "%#@VARIABLE@"
  public static func modalsUpsellAllCountriesFeatureMultipleDevices(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_multipleDevices", p1)
  }
  /// Block ads and malware with Netshield
  public static var modalsUpsellAllCountriesFeatureNetshield: String { return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_netshield") }
  /// Access global streaming services
  public static var modalsUpsellAllCountriesFeatureStreaming: String { return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_streaming") }
  /// Plural format key: "Access over %#@num_servers@ in %#@num_countries@"
  public static func modalsUpsellAllCountriesTitle(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "modals_upsell_all_countries_title", p1, p2)
  }
  /// And many more premium features
  public static var modalsUpsellFeaturesFooter: String { return LocalizedString.tr("Localizable", "modals_upsell_features_footer") }
  /// Moderate NAT, also known as Nat Type 2, can improve your online experience with various applications and online video games.
  /// 
  /// Unlock this and other features with a Plus plan.
  public static var modalsUpsellFeaturesModerateNatSubtitle: String { return LocalizedString.tr("Localizable", "modals_upsell_features_moderate_nat_subtitle") }
  /// Use ProtonVPN for any special need by allowing traffic to non-standard ports through the VPN network.
  /// 
  /// Unlock this and other features with a Plus plan.
  public static var modalsUpsellFeaturesSafeModeSubtitle: String { return LocalizedString.tr("Localizable", "modals_upsell_features_safe_mode_subtitle") }
  /// When you upgrade to Plus
  public static var modalsUpsellFeaturesSubtitle: String { return LocalizedString.tr("Localizable", "modals_upsell_features_subtitle") }
  /// What is Moderate NAT?
  public static var modalsUpsellModerateNatLearnMore: String { return LocalizedString.tr("Localizable", "modals_upsell_moderate_nat_learn_more") }
  /// Enable Moderate NAT
  public static var modalsUpsellModerateNatTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_moderate_nat_title") }
  /// Block ads and trackers
  public static var modalsUpsellNetShieldAds: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_ads") }
  /// Browse at the highest speeds
  public static var modalsUpsellNetShieldHighSpeed: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_highSpeed") }
  /// Protect your device from malware
  public static var modalsUpsellNetShieldMalware: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_malware") }
  /// Enjoy ad-free browsing with NetShield
  public static var modalsUpsellNetShieldTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_title") }
  /// Learn More
  public static var modalsUpsellSafeModeLearnMore: String { return LocalizedString.tr("Localizable", "modals_upsell_safe_mode_learn_more") }
  /// Allow traffic to non-standard ports
  public static var modalsUpsellSafeModeTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_safe_mode_title") }
  /// Protect yourself from network attacks
  public static var modalsUpsellSecureCoreAttacks: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_attacks") }
  /// Add another layer of encryption to your VPN connection
  public static var modalsUpsellSecureCoreLayer: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_layer") }
  /// Route through ultra secure servers in Switzerland, Sweden, and Iceland
  public static var modalsUpsellSecureCoreRoute: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_route") }
  /// Double the encryption with Secure Core
  public static var modalsUpsellSecureCoreTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_title") }
  /// Not now
  public static var modalsUpsellStayFree: String { return LocalizedString.tr("Localizable", "modals_upsell_stay_free") }
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
