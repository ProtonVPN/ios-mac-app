// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// Connection status title when user is connected to a VPN
  public static let connectionStatusProtected = LocalizedString.tr("Localizable", "connection_status_protected", fallback: "Protected")
  /// Connection status title when user is initiating connection to a VPN
  public static let connectionStatusProtecting = LocalizedString.tr("Localizable", "connection_status_protecting", fallback: "Protecting your digital identity")
  /// Connection status title when user is not connected to a VPN
  public static let connectionStatusUnprotected = LocalizedString.tr("Localizable", "connection_status_unprotected", fallback: "You are unprotected")
  /// Tab bar item title
  public static let countriesTabBarTitle = LocalizedString.tr("Localizable", "countries_tab_bar_title", fallback: "Countries")
  /// Tab bar item title
  public static let homeTabBarTitle = LocalizedString.tr("Localizable", "home_tab_bar_title", fallback: "Home")
  /// Tab bar item title
  public static let settingsTabBarTitle = LocalizedString.tr("Localizable", "settings_tab_bar_title", fallback: "Settings")
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension LocalizedString {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

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
