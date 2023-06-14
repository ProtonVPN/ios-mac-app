// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// Description of user account update screen
  public static var delinquentDescription: String { return LocalizedString.tr("Localizable", "delinquent_description", fallback: "You will be able to access premium features again after these are paid.") }
  /// Description of user account update screen
  public static var delinquentReconnectionDescription: String { return LocalizedString.tr("Localizable", "delinquent_reconnection_description", fallback: "You will be able to access premium features again after these are paid. For now, we are reconnecting to the fastest Free plan server available.") }
  /// Title of user account update screen
  public static var delinquentTitle: String { return LocalizedString.tr("Localizable", "delinquent_title", fallback: "Your VPN account has pending invoices") }
  /// Header of the view containing information about the server, from which the user will be disconnected
  public static var fromServerTitle: String { return LocalizedString.tr("Localizable", "from_server_title", fallback: "From server:") }
  /// Description of user account update screen
  public static var maximumDeviceLimit: String { return LocalizedString.tr("Localizable", "maximum_device_limit", fallback: "Please disconnect another device to connect to this one.") }
  /// Description of user account update screen part 1
  public static func maximumDevicePlanLimitPart1(_ p1: Any) -> String {
    return LocalizedString.tr("Localizable", "maximum_device_plan_limit_part_1", String(describing: p1), fallback: "Please disconnect another device to connect to this one or upgrade to %@")
  }
  /// Plural format key: " to get up to %#@num_devices@ connected at the same time."
  public static func maximumDevicePlanLimitPart2(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "maximum_device_plan_limit_part_2", p1, fallback: "Plural format key: \" to get up to %#@num_devices@ connected at the same time.\"")
  }
  /// Title of user account update screen
  public static var maximumDeviceTitle: String { return LocalizedString.tr("Localizable", "maximum_device_title", fallback: "You have reached your maximum device limit") }
  /// Common button title
  public static var modalsCommonCancel: String { return LocalizedString.tr("Localizable", "modals_common_cancel", fallback: "Cancel") }
  /// Common button title
  public static var modalsCommonLearnMore: String { return LocalizedString.tr("Localizable", "modals_common_learn_more", fallback: "Learn more") }
  /// Common button title
  public static var modalsCommonNext: String { return LocalizedString.tr("Localizable", "modals_common_next", fallback: "Next") }
  /// Positive user action on Secure Core discouragement screen
  public static var modalsDiscourageSecureCoreActivate: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_activate", fallback: "Activate Secure Core") }
  /// Turn off Secure Core discouragement screen
  public static var modalsDiscourageSecureCoreDontShow: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_dont_show", fallback: "Don’t show again") }
  /// Subtitle of the Secure Core discouragement screen
  public static var modalsDiscourageSecureCoreSubtitle: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_subtitle", fallback: "Secure Core offers the highest level of security and privacy, but it may reduce your internet speed. If you need more performance, you can disable Secure Core.") }
  /// Title of the Secure Core discouragement screen
  public static var modalsDiscourageSecureCoreTitle: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_title", fallback: "A note about speed...") }
  /// Upgrade plan button title
  public static var modalsGetPlus: String { return LocalizedString.tr("Localizable", "modals_get_plus", fallback: "Upgrade") }
  /// Learn more of the No Logs screen
  public static var modalsNoLogsExternalAudit: String { return LocalizedString.tr("Localizable", "modals_no_logs_external_audit", fallback: "Proton VPN's strict no-log policy is certified by an external audit.") }
  /// Feature of the No Logs screen
  public static var modalsNoLogsLogActivity: String { return LocalizedString.tr("Localizable", "modals_no_logs_log_activity", fallback: "We do not log your internet activity") }
  /// Feature of the No Logs screen
  public static var modalsNoLogsPrivacyFirst: String { return LocalizedString.tr("Localizable", "modals_no_logs_privacy_first", fallback: "Proton VPN is privacy first") }
  /// Feature of the No Logs screen
  public static var modalsNoLogsThirdParties: String { return LocalizedString.tr("Localizable", "modals_no_logs_third_parties", fallback: "We do not share any data with third parties") }
  /// Title of the No Logs screen
  public static var modalsNoLogsTitle: String { return LocalizedString.tr("Localizable", "modals_no_logs_title", fallback: "No logs and Swiss-based") }
  /// Feature of the All Countries upsell screen
  public static var modalsUpsellAllCountriesFeatureHighSpeed: String { return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_highSpeed", fallback: "Browse at the highest speeds (10 Gbps)") }
  /// Plural format key: "%#@VARIABLE@"
  public static func modalsUpsellAllCountriesFeatureMultipleDevices(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_multipleDevices", p1, fallback: "Plural format key: \"%#@VARIABLE@\"")
  }
  /// Feature of the All Countries upsell screen
  public static var modalsUpsellAllCountriesFeatureNetshield: String { return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_netshield", fallback: "Block ads and malware with NetShield") }
  /// Feature of the All Countries upsell screen
  public static var modalsUpsellAllCountriesFeatureStreaming: String { return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_streaming", fallback: "Access global streaming services") }
  /// Plural format key: "Access over %#@num_servers@ in %#@num_countries@"
  public static func modalsUpsellAllCountriesTitle(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "modals_upsell_all_countries_title", p1, p2, fallback: "Plural format key: \"Access over %#@num_servers@ in %#@num_countries@\"")
  }
  /// Footer of the All Countries upsell screen
  public static var modalsUpsellFeaturesFooter: String { return LocalizedString.tr("Localizable", "modals_upsell_features_footer", fallback: "And many more premium features") }
  /// Subtitle of the Moderate NAT upsell screen
  public static var modalsUpsellFeaturesModerateNatSubtitle: String { return LocalizedString.tr("Localizable", "modals_upsell_features_moderate_nat_subtitle", fallback: "Moderate NAT, also known as Nat Type 2, can improve your online experience with various applications and online video games.\n\nUnlock this and other features with a Plus plan.") }
  /// Subtitle of the Safe Mode upsell screen
  public static var modalsUpsellFeaturesSafeModeSubtitle: String { return LocalizedString.tr("Localizable", "modals_upsell_features_safe_mode_subtitle", fallback: "Have advanced or professional computing needs that require non-standard ports?\n\nUpgrade to VPN Plus to access this and other premium features.") }
  /// Subtitle of All Countries, NetShield and Secure Core upsell screens
  public static var modalsUpsellFeaturesSubtitle: String { return LocalizedString.tr("Localizable", "modals_upsell_features_subtitle", fallback: "When you upgrade to VPN Plus") }
  /// Learn more button title of the Moderate NAT upsell screen
  public static var modalsUpsellModerateNatLearnMore: String { return LocalizedString.tr("Localizable", "modals_upsell_moderate_nat_learn_more", fallback: "What is Moderate NAT?") }
  /// Title of the Moderate NAT upsell screen
  public static var modalsUpsellModerateNatTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_moderate_nat_title", fallback: "Enable Moderate NAT") }
  /// Feature of the NetShield upsell screen
  public static var modalsUpsellNetShieldAds: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_ads", fallback: "Block ads and trackers") }
  /// Feature of the NetShield upsell screen
  public static var modalsUpsellNetShieldHighSpeed: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_highSpeed", fallback: "Browse at the highest speeds") }
  /// Feature of the NetShield upsell screen
  public static var modalsUpsellNetShieldMalware: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_malware", fallback: "Protect your device from malware") }
  /// Title of the NetShield upsell screen
  public static var modalsUpsellNetShieldTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_title", fallback: "Enjoy ad-free browsing with NetShield") }
  /// Learn more button title of the Safe Mode upsell screen
  public static var modalsUpsellSafeModeLearnMore: String { return LocalizedString.tr("Localizable", "modals_upsell_safe_mode_learn_more", fallback: "Learn More") }
  /// Title of the Safe Mode upsell screen
  public static var modalsUpsellSafeModeTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_safe_mode_title", fallback: "Allow traffic to non-standard ports") }
  /// Feature of the Secure Core upsell screen
  public static var modalsUpsellSecureCoreAttacks: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_attacks", fallback: "Protect yourself from network attacks") }
  /// Feature of the Secure Core upsell screen
  public static var modalsUpsellSecureCoreLayer: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_layer", fallback: "Add another layer of encryption to your VPN connection") }
  /// Feature of the Secure Core upsell screen
  public static var modalsUpsellSecureCoreRoute: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_route", fallback: "Route through ultra secure servers in Switzerland, Sweden, and Iceland") }
  /// Title of the Secure Core upsell screen
  public static var modalsUpsellSecureCoreTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_title", fallback: "Double the encryption with Secure Core") }
  /// Dismiss upsell screen button title
  public static var modalsUpsellStayFree: String { return LocalizedString.tr("Localizable", "modals_upsell_stay_free", fallback: "Not now") }
  /// Title of "done" button in New Brand screen
  public static var newPlansBrandGotIt: String { return LocalizedString.tr("Localizable", "new_plans_brand_got_it", fallback: "Got it") }
  /// Subtitle of the New Brand screen
  public static var newPlansBrandSubtitle: String { return LocalizedString.tr("Localizable", "new_plans_brand_subtitle", fallback: "Introducing Proton’s refreshed look.\nMany services, one mission. Welcome to an internet where privacy is the default.") }
  /// Title of the New Brand screen
  public static var newPlansBrandTitle: String { return LocalizedString.tr("Localizable", "new_plans_brand_title", fallback: "Updated Proton, unified protection") }
  /// Description of user account update screen
  public static var subscriptionExpiredDescription: String { return LocalizedString.tr("Localizable", "subscription_expired_description", fallback: "Your subscription has been downgraded.") }
  /// Description of user account update screen
  public static var subscriptionExpiredReconnectionDescription: String { return LocalizedString.tr("Localizable", "subscription_expired_reconnection_description", fallback: "Your subscription has been downgraded, so we are reconnecting to the fastest available server.") }
  /// Title of user account update screen
  public static var subscriptionExpiredTitle: String { return LocalizedString.tr("Localizable", "subscription_expired_title", fallback: "Your VPN subscription plan has expired") }
  /// Plural format key: "Hundreds of servers in %#@num_countries@"
  public static func subscriptionUpgradeOption1(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "subscription_upgrade_option1", p1, fallback: "Plural format key: \"Hundreds of servers in %#@num_countries@\"")
  }
  /// Plural format key: "Connect up to %#@num_devices@ at the same time"
  public static func subscriptionUpgradeOption2(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "subscription_upgrade_option2", p1, fallback: "Plural format key: \"Connect up to %#@num_devices@ at the same time\"")
  }
  /// Feature list element in user account update screen
  public static var subscriptionUpgradeOption3: String { return LocalizedString.tr("Localizable", "subscription_upgrade_option3", fallback: "Advanced features: NetShield, Secure Core, Tor, P2P") }
  /// Header of the view containing information about the server, to which the user will be connected
  public static var toServerTitle: String { return LocalizedString.tr("Localizable", "to_server_title", fallback: "To server:") }
  /// Button action title in user account update screen
  public static var updateBilling: String { return LocalizedString.tr("Localizable", "update_billing", fallback: "Update My Billing") }
  /// Button action title in user account update screen
  public static var upgradeAgain: String { return LocalizedString.tr("Localizable", "upgrade_again", fallback: "Upgrade Again") }
  /// Button action title in user account update screen
  public static var upgradeNoThanks: String { return LocalizedString.tr("Localizable", "upgrade_no_thanks", fallback: "No Thanks") }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension LocalizedString {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = localizeStringAndFallbackToEn(key, table, value)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
