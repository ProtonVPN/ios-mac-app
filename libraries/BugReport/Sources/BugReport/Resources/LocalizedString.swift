// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// What's the issue?
  public static let br1Title = LocalizedString.tr("Localizable", "_br_1_title")
  /// Cancel
  public static let br2ButtonCancel = LocalizedString.tr("Localizable", "_br_2_button_cancel")
  /// Contact us
  public static let br2ButtonNext = LocalizedString.tr("Localizable", "_br_2_button_next")
  /// Didn't work?
  public static let br2Footer = LocalizedString.tr("Localizable", "_br_2_footer")
  /// These tips could help to solve your issue faster.
  public static let br2Subtitle = LocalizedString.tr("Localizable", "_br_2_subtitle")
  /// Quick fixes
  public static let br2Title = LocalizedString.tr("Localizable", "_br_2_title")
  /// Send report
  public static let br3ButtonSend = LocalizedString.tr("Localizable", "_br_3_button_send")
  /// Sending
  public static let br3ButtonSending = LocalizedString.tr("Localizable", "_br_3_button_sending")
  /// Email
  public static let br3Email = LocalizedString.tr("Localizable", "_br_3_email")
  /// A log is a type of file that shows us the actions you took that led to an error. We’ll only ever use them to help our engineers fix bugs.
  public static let br3LogsDescription = LocalizedString.tr("Localizable", "_br_3_logs_description")
  /// Error logs help us to get to the bottom of your issue. If you don’t include them, we might not be able to investigate fully.
  public static let br3LogsDisabled = LocalizedString.tr("Localizable", "_br_3_logs_disabled")
  /// Send error logs
  public static let br3LogsField = LocalizedString.tr("Localizable", "_br_3_logs_field")
  /// Try again
  public static let brFailureButtonRetry = LocalizedString.tr("Localizable", "_br_failure_button_retry")
  /// Troubleshoot
  public static let brFailureButtonTroubleshoot = LocalizedString.tr("Localizable", "_br_failure_button_troubleshoot")
  /// Your report wasn’t sent
  public static let brFailureTitle = LocalizedString.tr("Localizable", "_br_failure_title")
  /// Got it
  public static let brSuccessButton = LocalizedString.tr("Localizable", "_br_success_button")
  /// We’ll get back to you as soon as we can.
  public static let brSuccessSubtitle = LocalizedString.tr("Localizable", "_br_success_subtitle")
  /// Thanks for your feedback
  public static let brSuccessTitle = LocalizedString.tr("Localizable", "_br_success_title")
  /// Report an issue
  public static let brWindowTitle = LocalizedString.tr("Localizable", "_br_window_title")
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
    let format = BundleToken.bundle.localizedString(forKey: key, value: nil, table: table)
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
