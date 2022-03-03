// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// Cities
  public static var searchCities: String { return LocalizedString.tr("Localizable", "search_cities") }
  /// New York, London, Tokyo...
  public static var searchCitiesSample: String { return LocalizedString.tr("Localizable", "search_cities_sample") }
  /// Countries
  public static var searchCountries: String { return LocalizedString.tr("Localizable", "search_countries") }
  /// Switzerland, United States, Italy...
  public static var searchCountriesSample: String { return LocalizedString.tr("Localizable", "search_countries_sample") }
  /// Please try a different keyword
  public static var searchNoResultsSubtitle: String { return LocalizedString.tr("Localizable", "search_no_results_subtitle") }
  /// No results found
  public static var searchNoResultsTitle: String { return LocalizedString.tr("Localizable", "search_no_results_title") }
  /// Clear
  public static var searchRecentClear: String { return LocalizedString.tr("Localizable", "search_recent_clear") }
  /// Cancel
  public static var searchRecentClearCancel: String { return LocalizedString.tr("Localizable", "search_recent_clear_cancel") }
  /// Continue
  public static var searchRecentClearContinue: String { return LocalizedString.tr("Localizable", "search_recent_clear_continue") }
  /// Your search history will be lost. Continue?
  public static var searchRecentClearTitle: String { return LocalizedString.tr("Localizable", "search_recent_clear_title") }
  /// Recently viewed (%@)
  public static func searchRecentHeader(_ p1: Any) -> String {
    return LocalizedString.tr("Localizable", "search_recent_header", String(describing: p1))
  }
  /// Servers
  public static var searchServers: String { return LocalizedString.tr("Localizable", "search_servers") }
  /// JP#50, CA#3, IT#14...
  public static var searchServersSample: String { return LocalizedString.tr("Localizable", "search_servers_sample") }
  /// Search for any location
  public static var searchSubtitle: String { return LocalizedString.tr("Localizable", "search_subtitle") }
  /// Search
  public static var searchTitle: String { return LocalizedString.tr("Localizable", "search_title") }
  /// US regions
  public static var searchUsRegions: String { return LocalizedString.tr("Localizable", "search_us_regions") }
  /// California, Florida, Colorado...
  public static var searchUsRegionsSample: String { return LocalizedString.tr("Localizable", "search_us_regions_sample") }
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
