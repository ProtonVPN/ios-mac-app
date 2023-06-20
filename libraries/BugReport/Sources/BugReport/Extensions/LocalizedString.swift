// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// ReportBug 1st step title
  public static var br1Title: String { return LocalizedString.tr("Localizable", "_br_1_title", fallback: "What's the issue?") }
  /// ReportBug 2nd step (Quick fixes) cancel button
  public static var br2ButtonCancel: String { return LocalizedString.tr("Localizable", "_br_2_button_cancel", fallback: "Cancel") }
  /// ReportBug 2nd step (Quick fixes) button to go to the next step
  public static var br2ButtonNext: String { return LocalizedString.tr("Localizable", "_br_2_button_next", fallback: "Contact us") }
  /// ReportBug 2nd step (Quick fixes) text under the list of suggestions
  public static var br2Footer: String { return LocalizedString.tr("Localizable", "_br_2_footer", fallback: "Didn't work?") }
  /// ReportBug 2nd step (Quick fixes) subtitle
  public static var br2Subtitle: String { return LocalizedString.tr("Localizable", "_br_2_subtitle", fallback: "These tips could help to solve your issue faster.") }
  /// ReportBug 2nd step (Quick fixes) title
  public static var br2Title: String { return LocalizedString.tr("Localizable", "_br_2_title", fallback: "Quick fixes") }
  /// ReportBug 3rd step (form) send button
  public static var br3ButtonSend: String { return LocalizedString.tr("Localizable", "_br_3_button_send", fallback: "Send report") }
  /// ReportBug 3rd step (form) send button
  public static var br3ButtonSending: String { return LocalizedString.tr("Localizable", "_br_3_button_sending", fallback: "Sending") }
  /// ReportBug 3rd step (form) email field name
  public static var br3Email: String { return LocalizedString.tr("Localizable", "_br_3_email", fallback: "Email") }
  /// ReportBug 3rd step (form) logs description
  public static var br3LogsDescription: String { return LocalizedString.tr("Localizable", "_br_3_logs_description", fallback: "A log is a type of file that shows us the actions you took that led to an error. We’ll only ever use them to help our engineers fix bugs.") }
  /// ReportBug 3rd step (form): message shown if user disabled logs
  public static var br3LogsDisabled: String { return LocalizedString.tr("Localizable", "_br_3_logs_disabled", fallback: "Error logs help us to get to the bottom of your issue. If you don’t include them, we might not be able to investigate fully.") }
  /// ReportBug 3rd step (form) field to ask for includeing logs
  public static var br3LogsField: String { return LocalizedString.tr("Localizable", "_br_3_logs_field", fallback: "Send error logs") }
  /// ReportBug 3rd step (form) username field name
  public static var br3Username: String { return LocalizedString.tr("Localizable", "_br_3_username", fallback: "Username") }
  /// ReportBug success window: retry button
  public static var brFailureButtonRetry: String { return LocalizedString.tr("Localizable", "_br_failure_button_retry", fallback: "Try again") }
  /// ReportBug success window: troubleshoot button
  public static var brFailureButtonTroubleshoot: String { return LocalizedString.tr("Localizable", "_br_failure_button_troubleshoot", fallback: "Troubleshoot") }
  /// ReportBug success window: title text
  public static var brFailureTitle: String { return LocalizedString.tr("Localizable", "_br_failure_title", fallback: "Your report wasn’t sent") }
  /// ReportBug success window: button
  public static var brSuccessButton: String { return LocalizedString.tr("Localizable", "_br_success_button", fallback: "Got it") }
  /// ReportBug success window: subtitle text
  public static var brSuccessSubtitle: String { return LocalizedString.tr("Localizable", "_br_success_subtitle", fallback: "We’ll get back to you as soon as we can.") }
  /// ReportBug success window: title text
  public static var brSuccessTitle: String { return LocalizedString.tr("Localizable", "_br_success_title", fallback: "Thanks for your feedback") }
  /// ReportBugwindow title
  public static var brWindowTitle: String { return LocalizedString.tr("Localizable", "_br_window_title", fallback: "Report an issue") }
  /// Plural format key: "%#@STEP@ %#@STEPS@"
  public static func stepOf(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "_step_of", p1, p2, fallback: "Plural format key: \"%#@STEP@ %#@STEPS@\"")
  }
  /// Action button of the view nudging users to update before filling Bug Report
  public static var updateViewButton: String { return LocalizedString.tr("Localizable", "_update_view_button", fallback: "Update") }
  /// Description text of the view nudging users to update before filling Bug Report
  public static var updateViewDescription: String { return LocalizedString.tr("Localizable", "_update_view_description", fallback: "You’re more likely to have issues on older versions of Proton VPN.") }
  /// Title of the view nudging users to update before filling Bug Report
  public static var updateViewTitle: String { return LocalizedString.tr("Localizable", "_update_view_title", fallback: "Update Proton VPN") }
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
