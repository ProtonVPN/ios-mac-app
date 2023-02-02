// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// Proton VPN supports all devices, including Windows, macOS, and many others.
  public static var onboardingBeprotectedSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_beprotected_subtitle") }
  /// Be protected everywhere
  public static var onboardingBeprotectedTitle: String { return LocalizedString.tr("Localizable", "onboarding_beprotected_title") }
  /// Congratulations
  public static var onboardingCongratulations: String { return LocalizedString.tr("Localizable", "onboarding_congratulations") }
  /// Connect to a Plus server
  public static var onboardingConnectedConnectToPlus: String { return LocalizedString.tr("Localizable", "onboarding_connected_connect_to_plus") }
  /// Connected to:
  public static var onboardingConnectedConnectedTo: String { return LocalizedString.tr("Localizable", "onboarding_connected_connected_to") }
  /// Safely.
  public static var onboardingConnectedNote: String { return LocalizedString.tr("Localizable", "onboarding_connected_note") }
  /// Your connection is protected and you’re ready to browse the web.
  public static var onboardingConnectedSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_connected_subtitle") }
  /// Congratulations
  public static var onboardingConnectedTitle: String { return LocalizedString.tr("Localizable", "onboarding_connected_title") }
  /// Continue
  public static var onboardingContinue: String { return LocalizedString.tr("Localizable", "onboarding_continue") }
  /// Crash reports help us fix bugs, detect firewalls, and avoid VPN blocks.
  public static var onboardingCrashReportsDescription: String { return LocalizedString.tr("Localizable", "onboarding_crash_reports_description") }
  /// Share anonymous crash reports
  public static var onboardingCrashReportsTitle: String { return LocalizedString.tr("Localizable", "onboarding_crash_reports_title") }
  /// Done
  public static var onboardingDone: String { return LocalizedString.tr("Localizable", "onboarding_done") }
  /// Connect now
  public static var onboardingEstablishConnectNow: String { return LocalizedString.tr("Localizable", "onboarding_establish_connect_now") }
  /// We will connect you to the fastest and most stable server depending on your location.
  public static var onboardingEstablishNote: String { return LocalizedString.tr("Localizable", "onboarding_establish_note") }
  /// Plural format key: "Free subscription offers %#@num_servers@ in %#@num_countries@"
  public static func onboardingEstablishSubtitle(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "onboarding_establish_subtitle", p1, p2)
  }
  /// Establish your first connection
  public static var onboardingEstablishTitle: String { return LocalizedString.tr("Localizable", "onboarding_establish_title") }
  /// These statistics do not contain your IP address, and they cannot be used to identify you. We'll never share them with third parties.
  public static var onboardingFooter: String { return LocalizedString.tr("Localizable", "onboarding_footer") }
  /// Learn more
  public static var onboardingFooterLearnMore: String { return LocalizedString.tr("Localizable", "onboarding_footer_learn_more") }
  /// Get Plus
  public static var onboardingGetPlus: String { return LocalizedString.tr("Localizable", "onboarding_get_plus") }
  /// Block malware, ads, and trackers in browser and in all apps.
  public static var onboardingNetshieldSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_netshield_subtitle") }
  /// Block ads and much more
  public static var onboardingNetshieldTitle: String { return LocalizedString.tr("Localizable", "onboarding_netshield_title") }
  /// Next
  public static var onboardingNext: String { return LocalizedString.tr("Localizable", "onboarding_next") }
  /// Unable to establish a connection. Please try again later in the app.
  public static var onboardingNotConnectedError: String { return LocalizedString.tr("Localizable", "onboarding_not_connected_error") }
  /// You’re ready to browse the web.
  public static var onboardingNotConnectedSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_not_connected_subtitle") }
  /// Available with Plus
  public static var onboardingPlusOnly: String { return LocalizedString.tr("Localizable", "onboarding_plus_only") }
  /// Enjoy the world of privacy.
  public static var onboardingPurchasedNote: String { return LocalizedString.tr("Localizable", "onboarding_purchased_note") }
  /// Plural format key: "You now have access to %#@NUM_SEC_SERVERS@ and other premium features."
  public static func onboardingPurchasedSubtitle(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "onboarding_purchased_subtitle", p1)
  }
  /// Skip
  public static var onboardingSkip: String { return LocalizedString.tr("Localizable", "onboarding_skip") }
  /// Take a tour
  public static var onboardingTakeTour: String { return LocalizedString.tr("Localizable", "onboarding_take_tour") }
  /// Help us fight censorship
  public static var onboardingTelemetryTitle: String { return LocalizedString.tr("Localizable", "onboarding_telemetry_title") }
  /// Secure access to your favorite content from other countries — Now available on Android TV.
  public static var onboardingUnblockstreamingSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_unblockstreaming_subtitle") }
  /// Unblock streaming
  public static var onboardingUnblockstreamingTitle: String { return LocalizedString.tr("Localizable", "onboarding_unblockstreaming_title") }
  /// Plural format key: "Connect %#@NUM_DEVICES@ simultaneously"
  public static func onboardingUpsellFeatureMultipleDevices(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "onboarding_upsell_feature_multipleDevices", p1)
  }
  /// Plural format key: "Access all %#@NUM_SERVERS@ in %#@NUM_COUNTRIES@ with Plus"
  public static func onboardingUpsellTitle(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "onboarding_upsell_title", p1, p2)
  }
  /// Usage data helps us overcome VPN blocks and improve app performance.
  public static var onboardingUsageStatsDescription: String { return LocalizedString.tr("Localizable", "onboarding_usage_stats_description") }
  /// Share anonymous usage statistics
  public static var onboardingUsageStatsTitle: String { return LocalizedString.tr("Localizable", "onboarding_usage_stats_title") }
  /// Learn how to get the most out of Proton VPN in just a few seconds
  public static var onboardingWelcomeSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_welcome_subtitle") }
  /// Welcome to Proton VPN
  public static var onboardingWelcomeTitle: String { return LocalizedString.tr("Localizable", "onboarding_welcome_title") }
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
