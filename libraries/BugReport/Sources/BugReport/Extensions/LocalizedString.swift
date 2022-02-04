// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// What's the issue?
  public static var br1Title: String { return LocalizedString.tr("Localizable", "_br_1_title") }
  /// Cancel
  public static var br2ButtonCancel: String { return LocalizedString.tr("Localizable", "_br_2_button_cancel") }
  /// Contact us
  public static var br2ButtonNext: String { return LocalizedString.tr("Localizable", "_br_2_button_next") }
  /// Didn't work?
  public static var br2Footer: String { return LocalizedString.tr("Localizable", "_br_2_footer") }
  /// These tips could help to solve your issue faster.
  public static var br2Subtitle: String { return LocalizedString.tr("Localizable", "_br_2_subtitle") }
  /// Quick fixes
  public static var br2Title: String { return LocalizedString.tr("Localizable", "_br_2_title") }
  /// Send report
  public static var br3ButtonSend: String { return LocalizedString.tr("Localizable", "_br_3_button_send") }
  /// Sending
  public static var br3ButtonSending: String { return LocalizedString.tr("Localizable", "_br_3_button_sending") }
  /// Email
  public static var br3Email: String { return LocalizedString.tr("Localizable", "_br_3_email") }
  /// A log is a type of file that shows us the actions you took that led to an error. We’ll only ever use them to help our engineers fix bugs.
  public static var br3LogsDescription: String { return LocalizedString.tr("Localizable", "_br_3_logs_description") }
  /// Error logs help us to get to the bottom of your issue. If you don’t include them, we might not be able to investigate fully.
  public static var br3LogsDisabled: String { return LocalizedString.tr("Localizable", "_br_3_logs_disabled") }
  /// Send error logs
  public static var br3LogsField: String { return LocalizedString.tr("Localizable", "_br_3_logs_field") }
  /// Try again
  public static var brFailureButtonRetry: String { return LocalizedString.tr("Localizable", "_br_failure_button_retry") }
  /// Troubleshoot
  public static var brFailureButtonTroubleshoot: String { return LocalizedString.tr("Localizable", "_br_failure_button_troubleshoot") }
  /// Your report wasn’t sent
  public static var brFailureTitle: String { return LocalizedString.tr("Localizable", "_br_failure_title") }
  /// Got it
  public static var brSuccessButton: String { return LocalizedString.tr("Localizable", "_br_success_button") }
  /// We’ll get back to you as soon as we can.
  public static var brSuccessSubtitle: String { return LocalizedString.tr("Localizable", "_br_success_subtitle") }
  /// Thanks for your feedback
  public static var brSuccessTitle: String { return LocalizedString.tr("Localizable", "_br_success_title") }
  /// Report an issue
  public static var brWindowTitle: String { return LocalizedString.tr("Localizable", "_br_window_title") }
  /// Plural format key: "%#@STEP@ %#@STEPS@"
  public static func stepOf(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "_step_of", p1, p2)
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
