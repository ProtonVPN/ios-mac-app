// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// ProtonVPN supports all devices, including Windows, macOS, and many others.
  public static var onboardingBeprotectedSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_beprotected_subtitle") }
  /// Be protected everywhere
  public static var onboardingBeprotectedTitle: String { return LocalizedString.tr("Localizable", "onboarding_beprotected_title") }
  /// Connected to:
  public static var onboardingConnectedConnectedTo: String { return LocalizedString.tr("Localizable", "onboarding_connected_connected_to") }
  /// Safely.
  public static var onboardingConnectedNote: String { return LocalizedString.tr("Localizable", "onboarding_connected_note") }
  /// Your connection is protected and you’re ready to browse the web.
  public static var onboardingConnectedSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_connected_subtitle") }
  /// Congratulations
  public static var onboardingConnectedTitle: String { return LocalizedString.tr("Localizable", "onboarding_connected_title") }
  /// Done
  public static var onboardingDone: String { return LocalizedString.tr("Localizable", "onboarding_done") }
  /// Access all countries with PLUS
  public static var onboardingEstablishAccessAll: String { return LocalizedString.tr("Localizable", "onboarding_establish_access_all") }
  /// Connect now
  public static var onboardingEstablishConnectNow: String { return LocalizedString.tr("Localizable", "onboarding_establish_connect_now") }
  /// We will connect you to the fastest and most stable server depending on your location.
  public static var onboardingEstablishNote: String { return LocalizedString.tr("Localizable", "onboarding_establish_note") }
  /// FREE subscription offers 23 servers in 3 countries
  public static var onboardingEstablishSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_establish_subtitle") }
  /// Establish your first connection
  public static var onboardingEstablishTitle: String { return LocalizedString.tr("Localizable", "onboarding_establish_title") }
  /// Block malware, ads, and trackers in browser and in all apps.
  public static var onboardingNetshieldSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_netshield_subtitle") }
  /// Block ads and much more
  public static var onboardingNetshieldTitle: String { return LocalizedString.tr("Localizable", "onboarding_netshield_title") }
  /// Next
  public static var onboardingNext: String { return LocalizedString.tr("Localizable", "onboarding_next") }
  /// AVAILABLE WITH PLUS
  public static var onboardingPlusOnly: String { return LocalizedString.tr("Localizable", "onboarding_plus_only") }
  /// Skip
  public static var onboardingSkip: String { return LocalizedString.tr("Localizable", "onboarding_skip") }
  /// Take a tour
  public static var onboardingTakeTour: String { return LocalizedString.tr("Localizable", "onboarding_take_tour") }
  /// Secure access your favourite content from other countries, now also on AndroidTV.
  public static var onboardingUnblockstreamingSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_unblockstreaming_subtitle") }
  /// Unblock streaming
  public static var onboardingUnblockstreamingTitle: String { return LocalizedString.tr("Localizable", "onboarding_unblockstreaming_title") }
  /// Learn how to get the most out of ProtonVPN in just a few seconds
  public static var onboardingWelcomeSubtitle: String { return LocalizedString.tr("Localizable", "onboarding_welcome_subtitle") }
  /// Welcome to ProtonVPN
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
