// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// Section header in search
  public static var freeServers: String { return LocalizedString.tr("Localizable", "_free_servers", fallback: "Free Servers") }
  /// Section header in search
  public static var plusServers: String { return LocalizedString.tr("Localizable", "_plus_servers", fallback: "Plus Servers") }
  /// Placeholder text showing in the search bar on the search screen
  public static var searchBarPlaceholder: String { return LocalizedString.tr("Localizable", "search_bar_placeholder", fallback: "Country, City or Server") }
  /// Section header in search
  public static var searchCities: String { return LocalizedString.tr("Localizable", "search_cities", fallback: "Cities") }
  /// Sample cities the user can search for
  public static var searchCitiesSample: String { return LocalizedString.tr("Localizable", "search_cities_sample", fallback: "New York, London, Tokyo...") }
  /// Section header in search
  public static var searchCountries: String { return LocalizedString.tr("Localizable", "search_countries", fallback: "Countries") }
  /// Sample countries the user can search for
  public static var searchCountriesSample: String { return LocalizedString.tr("Localizable", "search_countries_sample", fallback: "Switzerland, United States, Italy...") }
  /// Subtitle shown when nothing is found in search
  public static var searchNoResultsSubtitle: String { return LocalizedString.tr("Localizable", "search_no_results_subtitle", fallback: "Please try a different keyword") }
  /// Title shown when nothing is found in search
  public static var searchNoResultsTitle: String { return LocalizedString.tr("Localizable", "search_no_results_title", fallback: "No results found") }
  /// Button to clear recent searches history
  public static var searchRecentClear: String { return LocalizedString.tr("Localizable", "search_recent_clear", fallback: "Clear") }
  /// Cancel button title in the alert asking for confirmation before deleting recent searches
  public static var searchRecentClearCancel: String { return LocalizedString.tr("Localizable", "search_recent_clear_cancel", fallback: "Cancel") }
  /// Confirmation button title in alert asking for confirmation before deleting recent searches
  public static var searchRecentClearContinue: String { return LocalizedString.tr("Localizable", "search_recent_clear_continue", fallback: "Continue") }
  /// Title for the alert asking for confirmation before deleting recent searches
  public static var searchRecentClearTitle: String { return LocalizedString.tr("Localizable", "search_recent_clear_title", fallback: "Your search history will be lost. Continue?") }
  /// Header for the recent searches section in search
  public static var searchRecentHeader: String { return LocalizedString.tr("Localizable", "search_recent_header", fallback: "Recently viewed") }
  /// Section header in search
  public static var searchResultsCities: String { return LocalizedString.tr("Localizable", "search_results_cities", fallback: "Cities") }
  /// Section header in search
  public static var searchResultsCountries: String { return LocalizedString.tr("Localizable", "search_results_countries", fallback: "Countries") }
  /// Section header in search
  public static var searchSecureCoreCountries: String { return LocalizedString.tr("Localizable", "search_secure_core_countries", fallback: "Secure Core countries") }
  /// Section header in Search
  public static var searchServers: String { return LocalizedString.tr("Localizable", "search_servers", fallback: "Servers") }
  /// Sample servers the user can search for
  public static var searchServersSample: String { return LocalizedString.tr("Localizable", "search_servers_sample", fallback: "JP#50, CA#3, IT#14...") }
  /// Title of the Search screen infographic
  public static var searchSubtitle: String { return LocalizedString.tr("Localizable", "search_subtitle", fallback: "Search for any location") }
  /// Title of the search screen
  public static var searchTitle: String { return LocalizedString.tr("Localizable", "search_title", fallback: "Search") }
  /// Subtitle for the upsell banner shown to free users in search
  public static var searchUpsellSubtitle: String { return LocalizedString.tr("Localizable", "search_upsell_subtitle", fallback: "More locations = more unblocked content + extra security + faster speeds") }
  /// Plural format key: "Access all %#@num_countries@"
  public static func searchUpsellTitle(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "search_upsell_title", p1, fallback: "Plural format key: \"Access all %#@num_countries@\"")
  }
  /// Section header in search
  public static var searchUsRegions: String { return LocalizedString.tr("Localizable", "search_us_regions", fallback: "US regions") }
  /// Sample US regions the user can search for
  public static var searchUsRegionsSample: String { return LocalizedString.tr("Localizable", "search_us_regions_sample", fallback: "California, Florida, Colorado...") }
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
