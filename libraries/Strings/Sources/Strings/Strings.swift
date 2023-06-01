// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// Countries tab in bottom menu
  public static var countriesTab: String { return LocalizedString.tr("Localizable", "_countries_tab", fallback: "Countries") }
  /// Home tab in bottom menu
  public static var homeTab: String { return LocalizedString.tr("Localizable", "_home_tab", fallback: "Home") }
  /// Settings tab in bottom menu
  public static var settingsTab: String { return LocalizedString.tr("Localizable", "_settings_tab", fallback: "Settings") }
  /// Plural format key: "%#@STEP@ %#@STEPS@"
  public static func stepOf(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "_step_of", p1, p2, fallback: "Plural format key: \"%#@STEP@ %#@STEPS@\"")
  }
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
