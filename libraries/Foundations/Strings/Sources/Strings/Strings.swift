// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum Localizable {
  /// 5 Connections
  public static var _5Connections: String { return Localizable.tr("Localizable", "_5_connections", fallback: "5 Connections") }
  /// Connect up to 5 devices
  /// at the same time
  public static var _5ConnectionsDescription: String { return Localizable.tr("Localizable", "_5_connections_description", fallback: "Connect up to 5 devices\nat the same time") }
  /// MacOS: About window title
  public static var about: String { return Localizable.tr("Localizable", "_about", fallback: "About") }
  /// Account tab button in settings window (MacOS and in several modals (both MacOS and iOS
  public static var account: String { return Localizable.tr("Localizable", "_account", fallback: "Account") }
  /// iOS: Message explaining that deleting account closes the VPN connection
  public static var accountDeletionConnectionWarning: String { return Localizable.tr("Localizable", "_account_deletion_connection_warning", fallback: "Deleting your account will end your VPN session.") }
  /// Alert title for account deletion error
  public static var accountDeletionError: String { return Localizable.tr("Localizable", "_account_deletion_error", fallback: "Error") }
  /// MacOS: Settings -> Account: name of field.
  public static var accountPlan: String { return Localizable.tr("Localizable", "_account_plan", fallback: "Account plan") }
  /// MacOS: Settings -> Account: name of field.
  public static var accountType: String { return Localizable.tr("Localizable", "_account_type", fallback: "Account type") }
  /// MacOS: About window
  public static var acknowledgements: String { return Localizable.tr("Localizable", "_acknowledgements", fallback: "Acknowledgements") }
  /// MacOS Profiles Overview: Table header for buttons column
  public static var action: String { return Localizable.tr("Localizable", "_action", fallback: "Action") }
  /// For buttons which have an action that connects to a server. [Redesign_2023]
  public static var actionConnect: String { return Localizable.tr("Localizable", "_action_connect", fallback: "Connect") }
  /// For buttons which have an action that disconnects from a server. [Redesign_2023]
  public static var actionDisconnect: String { return Localizable.tr("Localizable", "_action_disconnect", fallback: "Disconnect") }
  /// For buttons / navigation links which open a help menu or tooltip. [Redesign_2023]
  public static var actionHelp: String { return Localizable.tr("Localizable", "_action_help", fallback: "Help") }
  /// Home screen: pin this connection in the recents view. [Redesign_2023]
  public static var actionHomePin: String { return Localizable.tr("Localizable", "_action_home_pin", fallback: "Pin") }
  /// Home screen: unpin this connection from the recents view. [Redesign_2023]
  public static var actionHomeUnpin: String { return Localizable.tr("Localizable", "_action_home_unpin", fallback: "Unpin") }
  /// For buttons which have an action that removes an item. [Redesign_2023]
  public static var actionRemove: String { return Localizable.tr("Localizable", "_action_remove", fallback: "Remove") }
  /// Your connection needs to be restarted to apply this change
  public static var actionRequiresReconnect: String { return Localizable.tr("Localizable", "_action_requires_reconnect", fallback: "Your connection needs to be restarted to apply this change") }
  /// iOS widget help screen: title
  public static var activateWidget: String { return Localizable.tr("Localizable", "_activate_widget", fallback: "Activate Widget") }
  /// iOS widget help screen: text
  public static var activateWidgetStep1: String { return Localizable.tr("Localizable", "_activate_widget_step_1", fallback: "From your homescreen, swipe to the left most screen to access your widgets.") }
  /// iOS widget help screen: text
  public static var activateWidgetStep2: String { return Localizable.tr("Localizable", "_activate_widget_step_2", fallback: "Scroll all the way down and tap the edit button.") }
  /// iOS widget help screen: text
  public static var activateWidgetStep3: String { return Localizable.tr("Localizable", "_activate_widget_step_3", fallback: "Add the Proton VPN widget to the list of active widgets.") }
  /// Plan information
  public static var adblockerNetshieldFeature: String { return Localizable.tr("Localizable", "_adblocker_netshield_feature", fallback: "Adblocker (NetShield)") }
  /// Section title in Settings
  public static var advanced: String { return Localizable.tr("Localizable", "_advanced", fallback: "Advanced") }
  /// Plan information
  public static var advancedFeatures: String { return Localizable.tr("Localizable", "_advanced_features", fallback: "+ Advanced features") }
  /// Body of the deprecated protocol alert on iOS. Shown when the user attempts to connect to a profile with OpenVPN or IKEv2. 'Update' references the text of the alert button, and is emphasized with quotation marks (") which must be escaped with a single backslash (\).
  public static var alertProtocolDeprecatedBodyIos: String { return Localizable.tr("Localizable", "_alert_protocol_deprecated_body_ios", fallback: "This profile uses a protocol that is outdated and no longer supported. Click \"Update\" to switch to using the default Smart protocol.") }
  /// Body of the deprecated protocol alert on MacOS. Shown when the user attempts to connect to a profile with OpenVPN. 'Update' references the text of the alert button, and is emphasized with quotation marks (") which must be escaped with a single backslash (\). The 'Learn More' text is a hyperlink to https://protonvpn.com/blog/remove-vpn-protocols-apple
  public static var alertProtocolDeprecatedBodyMacos: String { return Localizable.tr("Localizable", "_alert_protocol_deprecated_body_macos", fallback: "This profile uses a protocol that is outdated and no longer supported. Click \"Update\" to switch to using the default Smart protocol. Learn more") }
  /// Text for the 'Close' action of the deprecated protocol alert.
  public static var alertProtocolDeprecatedClose: String { return Localizable.tr("Localizable", "_alert_protocol_deprecated_close", fallback: "Close") }
  /// Text for the 'Enable Smart protocol' action of the deprecated protocol alert. The alert is shown when the user attempts to quick connect, or connect to a profile that uses a deprecated protocol. This action enables Smart protocol, but does not continue the connection.
  public static var alertProtocolDeprecatedEnableSmart: String { return Localizable.tr("Localizable", "_alert_protocol_deprecated_enable_smart", fallback: "Update") }
  /// Text for the 'Learn more' action of the deprecated protocol alert on iOS. When tapped, opens https://protonvpn.com/blog/remove-vpn-protocols-apple in the device browser
  public static var alertProtocolDeprecatedLearnMore: String { return Localizable.tr("Localizable", "_alert_protocol_deprecated_learn_more", fallback: "Learn more") }
  /// The text inside the deprecated protocol alert that should be displayed as a hyperlink to https://protonvpn.com/blog/remove-vpn-protocols-apple (MacOS only)
  public static var alertProtocolDeprecatedLinkText: String { return Localizable.tr("Localizable", "_alert_protocol_deprecated_link_text", fallback: "Learn more") }
  /// Title of the deprecated protocol alert. Shown when the user attempts to connect to a profile with OpenVPN
  public static var alertProtocolDeprecatedTitle: String { return Localizable.tr("Localizable", "_alert_protocol_deprecated_title", fallback: "Protocol Unavailable") }
  /// Account plan description
  public static var allCountries: String { return Localizable.tr("Localizable", "_all_countries", fallback: "60+ countries") }
  /// Under maintenance alert
  public static var allServersInCountryUnderMaintenance: String { return Localizable.tr("Localizable", "_all_servers_in_country_under_maintenance", fallback: "All servers in this country are under maintenance. Please connect to another country.") }
  /// Under maintenance alert
  public static var allServersInProfileUnderMaintenance: String { return Localizable.tr("Localizable", "_all_servers_in_profile_under_maintenance", fallback: "Profile server(s) under maintenance") }
  /// Under maintenance alert
  public static var allServersUnderMaintenance: String { return Localizable.tr("Localizable", "_all_servers_under_maintenance", fallback: "All servers are under maintenance. This usually means either there are technical difficulties on Proton VPN's side, or your network is limited.") }
  /// Allow
  public static var allow: String { return Localizable.tr("Localizable", "_allow", fallback: "Allow") }
  /// In order to allow LAN access, kill switch must be turned off.
  /// 
  /// Continue?
  public static var allowLanDescription: String { return Localizable.tr("Localizable", "_allow_lan_description", fallback: "In order to allow LAN access, kill switch must be turned off.\n\nContinue?") }
  /// Allows to bypass the VPN and connect to devices on your local network, like your printer.
  public static var allowLanInfo: String { return Localizable.tr("Localizable", "_allow_lan_info", fallback: "Allows to bypass the VPN and connect to devices on your local network, like your printer.") }
  /// Note that your connection needs to be restarted to apply this change
  public static var allowLanNote: String { return Localizable.tr("Localizable", "_allow_lan_note", fallback: "Note that your connection needs to be restarted to apply this change") }
  /// Allow LAN connections
  public static var allowLanTitle: String { return Localizable.tr("Localizable", "_allow_lan_title", fallback: "Allow LAN connections") }
  /// iOS: button for switching from sign-up to sign-in screen
  public static var alreadyHaveAccount: String { return Localizable.tr("Localizable", "_already_have_account", fallback: "I already have an account") }
  /// iOS Settings: toggle name
  public static var alwaysOnVpn: String { return Localizable.tr("Localizable", "_always_on_vpn", fallback: "Always-on VPN") }
  /// iOS Settinsg screen: always-on description under the switch
  public static var alwaysOnVpnTooltipIos: String { return Localizable.tr("Localizable", "_always_on_vpn_tooltip_ios", fallback: "Always-on VPN reestablishes a secure VPN connection swiftly and automatically. For your security, this feature is always on.") }
  /// Disconnect notification
  public static var alwaysOnWillReconnect: String { return Localizable.tr("Localizable", "_always_on_will_reconnect", fallback: "Always-on VPN will reconnect you automatically") }
  /// iOS Settings: applications logs row
  public static var applicationLogs: String { return Localizable.tr("Localizable", "_application_logs", fallback: "Application Logs") }
  /// Applying settings
  public static var applyingSettings: String { return Localizable.tr("Localizable", "_applying_settings_", fallback: "Applying settings") }
  /// MacOS: label in server info view (shown after click on Info icon in countries list
  public static var autoAssigned: String { return Localizable.tr("Localizable", "_auto_assigned", fallback: "Auto assigned") }
  /// MacOS: Settings -> Connection: name of field.
  public static var autoConnect: String { return Localizable.tr("Localizable", "_auto_connect", fallback: "Auto Connect") }
  /// MacOS: Settings -> Connection: description.
  public static var autoConnectTooltip: String { return Localizable.tr("Localizable", "_auto_connect_tooltip", fallback: "On app start, you are connected to the selected profile") }
  /// This is for a tooltip appearing over a "VPN Business" badge. Appears for users of the VPN Essentials plan to communicate the fact that their current plan does not support a given feature.
  public static var availableWithVpnBusinessTooltip: String { return Localizable.tr("Localizable", "_available_with_vpn_business_tooltip", fallback: "Available with VPN Business.") }
  /// Error title warning the user that one of the device's interfaces has a badly-configured local network. This can result in traffic leaks if the user is not careful.
  public static var badInterfaceIpRangeAlertTitle: String { return Localizable.tr("Localizable", "_bad_interface_ip_range_alert_title", fallback: "Bad Network Interface") }
  /// Common word
  public static var cancel: String { return Localizable.tr("Localizable", "_cancel", fallback: "Cancel") }
  /// This will cancel any re-connection attempt and leave you disconnected
  public static var cancelReconnection: String { return Localizable.tr("Localizable", "_cancel_reconnection", fallback: "This will cancel any re-connection attempt and leave you disconnected") }
  /// Warning text that changing the VPN protocol will require the current VPN session to be disconnected
  public static var changeProtocolDisconnectWarning: String { return Localizable.tr("Localizable", "_change_protocol_disconnect_warning", fallback: "Changing protocols will end your current VPN session.") }
  /// Title of the change server button
  public static var changeServer: String { return Localizable.tr("Localizable", "_change_server", fallback: "Change server") }
  /// Changing settings title
  public static var changeSettings: String { return Localizable.tr("Localizable", "_change_settings", fallback: "Change settings") }
  /// MacOS: About window
  public static var changelog: String { return Localizable.tr("Localizable", "_changelog", fallback: "Changelog") }
  /// iOS: new profkle can't be created because not all required fields are filled
  public static var checkIfFieldsPresent: String { return Localizable.tr("Localizable", "_check_if_fields_present", fallback: "Please check if all the fields are filled in") }
  /// iOS plan selection: header
  public static var choosePlan: String { return Localizable.tr("Localizable", "_choose_plan", fallback: "Choose Subscription") }
  /// iOS status view
  public static var city: String { return Localizable.tr("Localizable", "_city", fallback: "City") }
  /// Main mac app menu item
  public static var clearApplicationData: String { return Localizable.tr("Localizable", "_clear_application_data", fallback: "Clear Application Data") }
  /// Common word
  public static var close: String { return Localizable.tr("Localizable", "_close", fallback: "Close") }
  /// Collapse list of servers
  public static var collapseListOfServers: String { return Localizable.tr("Localizable", "_collapse_list_of_servers", fallback: "Collapse list of servers") }
  /// Profile create/change form
  public static var color: String { return Localizable.tr("Localizable", "_color", fallback: "Color") }
  /// MacOS: button in login screen
  public static var commonIssues: String { return Localizable.tr("Localizable", "_common_issues", fallback: "Common sign in issues") }
  /// Common word
  public static var connect: String { return Localizable.tr("Localizable", "_connect", fallback: "Connect") }
  /// Common word
  public static var connected: String { return Localizable.tr("Localizable", "_connected", fallback: "Connected") }
  /// iOS status view
  public static var connectedTo: String { return Localizable.tr("Localizable", "_connected_to", fallback: "Connected to") }
  /// %@ is a country followed by a server e.g. Connected to Switzerland CH#1
  public static func connectedToVpn(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_connected_to_vpn", String(describing: p1), fallback: "Connected to %@")
  }
  /// iOS: main button in tabbar during connecting to vpn phase
  public static var connecting: String { return Localizable.tr("Localizable", "_connecting", fallback: "Connecting") }
  /// MacOS: connecting overlay. %@ is a country followed by a server e.g. Connecting to Switzerland CH#1. iOS: String in connection status screen. %@ is a country followed by `>> second country` in case it is a connection with SecureCore
  public static func connectingTo(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_connecting_to", String(describing: p1), fallback: "Connecting to %@")
  }
  /// MacOS: connecting overlay. %@ is a failure or timeout e.g. Connecting failed
  public static func connectingVpn(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_connecting_vpn", String(describing: p1), fallback: "Connecting %@")
  }
  /// Connecting...
  public static var connectingDotDotDot: String { return Localizable.tr("Localizable", "_connectingDotDotDot", fallback: "Connecting...") }
  /// MacOS Profiles Overview: Table column header; MacOS Settings Tab title;
  public static var connection: String { return Localizable.tr("Localizable", "_connection", fallback: "Connection") }
  /// Connection card in home tab, VoiceOver label for accessibility users. %@ is a country name. [Redesign_2023]
  public static func connectionCardAccessibilityBrowsingFrom(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_connection_card_accessibility_browsing_from", String(describing: p1), fallback: "You are safely browsing from %@.")
  }
  /// Connection card in home tab, VoiceOver connection label for accessibility users. %@ is a country name. [Redesign_2023]
  public static func connectionCardAccessibilityConnectingTo(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_connection_card_accessibility_connecting_to", String(describing: p1), fallback: "Connecting to %@.")
  }
  /// Connection card in home tab, VoiceOver connection label for accessibility users. %@ is a country name. [Redesign_2023]
  public static func connectionCardAccessibilityLastConnectedTo(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_connection_card_accessibility_last_connected_to", String(describing: p1), fallback: "You were last connected to %@.")
  }
  /// For buttons which have an action that cancels connecting to a server. [Redesign_2023]
  public static var connectionCardActionCancel: String { return Localizable.tr("Localizable", "_connection_card_action_cancel", fallback: "Cancel") }
  /// Connection card in home tab: "Connecting to <country name>" [Redesign_2023]
  public static var connectionCardConnectingTo: String { return Localizable.tr("Localizable", "_connection_card_connecting_to", fallback: "Connecting to...") }
  /// Connection card in home tab: "Last connected to... <country name>" [Redesign_2023]
  public static var connectionCardLastConnectedTo: String { return Localizable.tr("Localizable", "_connection_card_last_connected_to", fallback: "Last connected to") }
  /// Connection card in home tab: "Safely browsing from... <country name>" [Redesign_2023]
  public static var connectionCardSafelyBrowsingFrom: String { return Localizable.tr("Localizable", "_connection_card_safely_browsing_from", fallback: "Browsing safely from") }
  /// Connection details screen: City (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsCity: String { return Localizable.tr("Localizable", "_connection_details_city", fallback: "City") }
  /// Connection details screen: Connected for (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsConnectedFor: String { return Localizable.tr("Localizable", "_connection_details_connected_for", fallback: "Connected for") }
  /// Connection details screen: Country (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsCountry: String { return Localizable.tr("Localizable", "_connection_details_country", fallback: "Country") }
  /// Connection details screen: P2P feature description (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsFeatureDescriptionP2p: String { return Localizable.tr("Localizable", "_connection_details_feature_description_p2p", fallback: "Download files through BitTorrent and other file sharing protocols") }
  /// Connection details screen: Secure core description (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsFeatureDescriptionSecureCore: String { return Localizable.tr("Localizable", "_connection_details_feature_description_secure_core", fallback: "Download files through BitTorrent and other file sharing protocols") }
  /// Connection details screen: Smart routing description (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsFeatureDescriptionSmartRouting: String { return Localizable.tr("Localizable", "_connection_details_feature_description_smart_routing", fallback: "Servers are physically located in Singapore, but you’ll appear to be browsing from Thailand.") }
  /// Connection details screen: Streaming feature description (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsFeatureDescriptionStreaming: String { return Localizable.tr("Localizable", "_connection_details_feature_description_streaming", fallback: "Watch your favorite movies and TV shows.") }
  /// Connection details screen: Tor feature description (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsFeatureDescriptionTor: String { return Localizable.tr("Localizable", "_connection_details_feature_description_tor", fallback: "Connect to the Tor anonymity network using any browser") }
  /// Connection details screen: P2P feature title (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsFeatureTitleP2p: String { return Localizable.tr("Localizable", "_connection_details_feature_title_p2p", fallback: "P2P") }
  /// Connection details screen: Secure core title (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsFeatureTitleSecureCore: String { return Localizable.tr("Localizable", "_connection_details_feature_title_secure_core", fallback: "Secure Core") }
  /// Connection details screen: Smart Routing title (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsFeatureTitleSmartRouting: String { return Localizable.tr("Localizable", "_connection_details_feature_title_smart_routing", fallback: "Smart Routing") }
  /// Connection details screen: Streaming feature title (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsFeatureTitleStreaming: String { return Localizable.tr("Localizable", "_connection_details_feature_title_streaming", fallback: "Streaming") }
  /// Connection details screen: Tor feature title (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsFeatureTitleTor: String { return Localizable.tr("Localizable", "_connection_details_feature_title_tor", fallback: "Tor") }
  /// Connection details screen: Title of the section that lists VPN connection features (like P2P, Tor, etc.) (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsFeaturesTitle: String { return Localizable.tr("Localizable", "_connection_details_features_title", fallback: "Features") }
  /// Connection details screen: Info button text, that show more info about given VPN feature (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsInfoButton: String { return Localizable.tr("Localizable", "_connection_details_info_button", fallback: "Info") }
  /// Connection details screen: IP view (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsIpviewIpMy: String { return Localizable.tr("Localizable", "_connection_details_ipview_ip_my", fallback: "My IP") }
  /// Connection details screen: IP view - text shown instead of IP when app can't determine the IP address (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsIpviewIpUnavailable: String { return Localizable.tr("Localizable", "_connection_details_ipview_ip_unavailable", fallback: "Unavailable") }
  /// Connection details screen: IP view (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsIpviewIpVpn: String { return Localizable.tr("Localizable", "_connection_details_ipview_ip_vpn", fallback: "VPN IP") }
  /// Connection details screen: Protocol (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsProtocol: String { return Localizable.tr("Localizable", "_connection_details_protocol", fallback: "Protocol") }
  /// Connection details screen: Server (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsServer: String { return Localizable.tr("Localizable", "_connection_details_server", fallback: "Server") }
  /// Connection details screen: Server load (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsServerLoad: String { return Localizable.tr("Localizable", "_connection_details_server_load", fallback: "Server load") }
  /// Connection details screen: Title before connection details table (macOS and iOS) [Redesign_2023]
  public static var connectionDetailsTitle: String { return Localizable.tr("Localizable", "_connection_details_title", fallback: "Connection details") }
  /// Connection error translation. iOS quick connect widget: text shown on error.
  public static var connectionFailed: String { return Localizable.tr("Localizable", "_connection_failed", fallback: "Connection Failed") }
  /// Profile create/change form
  public static var connectionSettings: String { return Localizable.tr("Localizable", "_connection_settings", fallback: "Connection settings") }
  /// macOS: Text on connection overlay shown after connection timed out
  public static var connectionTimedOut: String { return Localizable.tr("Localizable", "_connection_timed_out", fallback: "Connection timed out") }
  /// Text that should be bold in _connection_timed_out string
  public static var connectionTimedOutBold: String { return Localizable.tr("Localizable", "_connection_timed_out_bold", fallback: "timed out") }
  /// Header before the list of connections available for free users (in the country list)
  public static var connectionsFree: String { return Localizable.tr("Localizable", "_connections_free", fallback: "Free connections") }
  /// Text addressing to contact costumer support on several sites of the app
  public static var contactOurSupport: String { return Localizable.tr("Localizable", "_contact_our_support", fallback: "Contact our support") }
  /// Continue
  public static var `continue`: String { return Localizable.tr("Localizable", "_continue", fallback: "Continue") }
  /// iOS: Countries screen title, tab bar item title; MacOS: TabBar tab title;
  public static var countries: String { return Localizable.tr("Localizable", "_countries", fallback: "Countries") }
  /// Plural format key: "%#@VARIABLE@"
  public static func countriesCount(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "_countries_count", p1, fallback: "Plural format key: \"%#@VARIABLE@\"")
  }
  /// Plural format key: "%#@VARIABLE@"
  public static func countriesCountPlus(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "_countries_count_plus", p1, fallback: "Plural format key: \"%#@VARIABLE@\"")
  }
  /// iOS: countries list section header
  public static var countriesFree: String { return Localizable.tr("Localizable", "_countries_free", fallback: "Free countries") }
  /// iOS: countries list section header
  public static var countriesPremium: String { return Localizable.tr("Localizable", "_countries_premium", fallback: "Premium countries") }
  /// Countries tab in bottom menu [Redesign_2023]
  public static var countriesTab: String { return Localizable.tr("Localizable", "_countries_tab", fallback: "Countries") }
  /// Profile create/edit menu
  public static var country: String { return Localizable.tr("Localizable", "_country", fallback: "Country") }
  /// Error when user hasn't selected profile country
  public static var countrySelectionIsRequired: String { return Localizable.tr("Localizable", "_country_selection_is_required", fallback: "Please select a country") }
  /// Under maintenance alert
  public static func countryServersUnderMaintenance(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_country_servers_under_maintenance", String(describing: p1), fallback: "%@ servers under maintenance")
  }
  /// MacOS: button in login screen
  public static var createAccount: String { return Localizable.tr("Localizable", "_create_account", fallback: "Create Account") }
  /// MacOS: Buttons in several places; iOS: profile creation screen title
  public static var createNewProfile: String { return Localizable.tr("Localizable", "_create_new_profile", fallback: "Create Profile") }
  /// Create Profile
  public static var createProfile: String { return Localizable.tr("Localizable", "_create_profile", fallback: "Create Profile") }
  /// MacOS: profile creation cancel alert text
  public static var currentSelectionWillBeLost: String { return Localizable.tr("Localizable", "_current_selection_will_be_lost", fallback: "By continuing, current selection will be lost. Do you want to continue?") }
  /// iOS: data disclaimer screen button
  public static var dataDisclaimerAgree: String { return Localizable.tr("Localizable", "_data_disclaimer_agree", fallback: "Agree & Continue") }
  /// iOS: data disclaimer screen
  public static var dataDisclaimerDeviceDetails: String { return Localizable.tr("Localizable", "_data_disclaimer_device_details", fallback: "Your device model and OS version") }
  /// iOS: data disclaimer screen
  public static func dataDisclaimerText(_ p1: Any, _ p2: Any) -> String {
    return Localizable.tr("Localizable", "_data_disclaimer_text", String(describing: p1), String(describing: p2), fallback: "Proton VPN is committed to protecting and respecting your privacy. It is our overriding policy to collect as little user data as possible to ensure a private and anonymous user experience in the use of the App, specifically:\n\n%@ – to log you in, help to recover a lost password, and send important service updates.\n\n%@ – for crash reports and errors only.\n\nThe Proton VPN App does not process any user information besides this data. We don't log your online activity nor any personal identifiable information. All data listed above is stored and processed on Proton VPN's own system, with no third party ever having access to it.")
  }
  /// iOS: data disclaimer screen
  public static var dataDisclaimerTitle: String { return Localizable.tr("Localizable", "_data_disclaimer_title", fallback: "Protect yourself online") }
  /// iOS: data disclaimer screen
  public static var dataDisclaimerUserDetails: String { return Localizable.tr("Localizable", "_data_disclaimer_user_details", fallback: "Username, email address") }
  /// Profile create/change form
  public static var defaultProfileTooltip: String { return Localizable.tr("Localizable", "_default_profile_tooltip", fallback: "\"Quick Connect\" button uses default profile.\n") }
  /// Common word
  public static var delete: String { return Localizable.tr("Localizable", "_delete", fallback: "Delete") }
  /// MacOS: clear application data alert
  public static var deleteApplicationDataPopupBody: String { return Localizable.tr("Localizable", "_delete_application_data_popup_body", fallback: "All Proton VPN data will be deleted and the application will quit. Do you wish to continue?") }
  /// MacOS: clear application data alert
  public static var deleteApplicationDataPopupTitle: String { return Localizable.tr("Localizable", "_delete_application_data_popup_title", fallback: "Clear application data") }
  /// Button
  public static var deleteProfile: String { return Localizable.tr("Localizable", "_delete_profile", fallback: "Delete profile") }
  /// MacOS: profile deletion warning
  public static var deleteProfileHeader: String { return Localizable.tr("Localizable", "_delete_profile_header", fallback: "Delete Profile") }
  /// MacOS: profile deletion warning
  public static var deleteProfileWarning: String { return Localizable.tr("Localizable", "_delete_profile_warning", fallback: "The profile will be permanently deleted. Do you want to continue?") }
  /// You will be able to access premium features again after these are paid.
  public static var delinquentDescription: String { return Localizable.tr("Localizable", "_delinquent_description", fallback: "You will be able to access premium features again after these are paid.") }
  /// You will be able to access premium features again after these are paid. For now, we are reconnecting to the fastest Free plan server available.
  public static var delinquentReconnectionDescription: String { return Localizable.tr("Localizable", "_delinquent_reconnection_description", fallback: "You will be able to access premium features again after these are paid. For now, we are reconnecting to the fastest Free plan server available.") }
  /// Your VPN account has pending invoices
  public static var delinquentTitle: String { return Localizable.tr("Localizable", "_delinquent_title", fallback: "Your VPN account has pending invoices") }
  /// Delinquent user alert
  public static var delinquentUserDescription: String { return Localizable.tr("Localizable", "_delinquent_user_description", fallback: "Your account currently has an overdue invoice. Please pay all unpaid invoices at account.protonvpn.com") }
  /// Delinquent user alert
  public static var delinquentUserTitle: String { return Localizable.tr("Localizable", "_delinquent_user_title", fallback: "Unpaid invoice") }
  /// Profile create/change form
  public static var differentServerEachTime: String { return Localizable.tr("Localizable", "_different_server_each_time", fallback: "Different server each time") }
  /// Button in some alerts
  public static var disable: String { return Localizable.tr("Localizable", "_disable", fallback: "Disable") }
  /// Common word
  public static var disabled: String { return Localizable.tr("Localizable", "_disabled", fallback: "Disabled") }
  /// Common word
  public static var disconnect: String { return Localizable.tr("Localizable", "_disconnect", fallback: "Disconnect") }
  /// Common word
  public static var disconnected: String { return Localizable.tr("Localizable", "_disconnected", fallback: "Disconnected") }
  /// Status of VPN connection reported by Siri
  public static var disconnecting: String { return Localizable.tr("Localizable", "_disconnecting", fallback: "Disconnecting") }
  /// MacOS: Settings -> Connection: name of field.
  public static var dnsLeakProtection: String { return Localizable.tr("Localizable", "_dns_leak_protection", fallback: "DNS Leak Protection") }
  /// MacOS: Settings -> Connection: description.
  public static var dnsLeakProtectionTooltip: String { return Localizable.tr("Localizable", "_dns_leak_protection_tooltip", fallback: "Prevent leaking details of DNS queries to third parties. Always on.") }
  /// Alert message during In App Purchase
  public static var doYouWantToActivateSubscriptionFor: String { return Localizable.tr("Localizable", "_do_you_want_to_activate_subscription_for", fallback: "Do you want to activate the purchased subscription for ") }
  /// Common word
  public static var done: String { return Localizable.tr("Localizable", "_done", fallback: "Done") }
  /// Our partners
  public static var dwPartner2022PartnersTitle: String { return Localizable.tr("Localizable", "_dw-partner-2022_partners_title", fallback: "Our partners") }
  /// MacOS: Settings -> General: name of field.
  public static var earlyAccess: String { return Localizable.tr("Localizable", "_early_access", fallback: "Early Access") }
  /// MacOS: Settings -> General: description.
  public static var earlyAccessTooltip: String { return Localizable.tr("Localizable", "_early_access_tooltip", fallback: "Be the first to get the latest updates. Please keep in mind that early versions may be less stable.") }
  /// Common word
  public static var edit: String { return Localizable.tr("Localizable", "_edit", fallback: "Edit") }
  /// Common word
  public static var enabled: String { return Localizable.tr("Localizable", "_enabled", fallback: "Enabled") }
  /// iOS: placeholder for email field in signup and email verification screens
  public static var enterEmailAddress: String { return Localizable.tr("Localizable", "_enter_email_address", fallback: "Enter email address") }
  /// Profile create/change form
  public static var enterProfileName: String { return Localizable.tr("Localizable", "_enter_profile_name", fallback: "Enter Profile Name") }
  /// iOS: placeholder for code in human verification code form
  public static var enterVerificationCode: String { return Localizable.tr("Localizable", "_enter_verification_code", fallback: "123 456") }
  /// Error decoding an object
  public static func errorDecode(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_error_decode", String(describing: p1), fallback: "Failed to decode archived data in class: %@")
  }
  /// Internal application error
  public static var errorEmailVerificationDisabled: String { return Localizable.tr("Localizable", "_error_email_verification_disabled", fallback: "Email verification temporarily disabled") }
  /// Error try to restore user from the session
  public static var errorFetchSession: String { return Localizable.tr("Localizable", "_error_fetch_session", fallback: "Can't find user from the session") }
  /// Unknown error that has no better description
  public static var errorInternalError: String { return Localizable.tr("Localizable", "_error_internal_error", fallback: "Internal API error") }
  /// Error writing to system keychain
  public static var errorKeychainWrite: String { return Localizable.tr("Localizable", "_error_keychain_write", fallback: "Proton couldn't communicate with your device. Please try again later.") }
  /// The TLS certificate validation failed when trying to connect to the Proton VPN API. Your current internet connection may be monitored. To keep your data secure, we are preventing the app from accessing the Proton VPN API.
  /// To sign in or access your account, switch to a new network and try to connect again.
  public static var errorMitmDescription: String { return Localizable.tr("Localizable", "_error_mitm_description", fallback: "The TLS certificate validation failed when trying to connect to the Proton VPN API. Your current internet connection may be monitored. To keep your data secure, we are preventing the app from accessing the Proton VPN API.\nTo sign in or access your account, switch to a new network and try to connect again.") }
  /// Insecure connection
  public static var errorMitmTitle: String { return Localizable.tr("Localizable", "_error_mitm_title", fallback: "Insecure connection") }
  /// The TLS certificate validation failed when trying to connect to the VPN server. Your current internet connection may be monitored. To keep your data secure, we are preventing the app from accessing this VPN server.
  /// Please select other server.
  public static var errorMitmVpnDescription: String { return Localizable.tr("Localizable", "_error_mitm_vpn_description", fallback: "The TLS certificate validation failed when trying to connect to the VPN server. Your current internet connection may be monitored. To keep your data secure, we are preventing the app from accessing this VPN server.\nPlease select other server.") }
  /// Generic sign in error
  public static var errorSignInAgain: String { return Localizable.tr("Localizable", "_error_sign_in_again", fallback: "Sorry, something went wrong. Please sign in again.") }
  /// Internal error message when there is a problem with initializing tls and connection cannot be established.
  public static var errorTlsInitialisation: String { return Localizable.tr("Localizable", "_error_tls_initialisation", fallback: "TLS initialisation error") }
  /// Internal error message when there is a problem with server certificate and connection cannot be established.
  public static var errorTlsServerVerification: String { return Localizable.tr("Localizable", "_error_tls_server_verification", fallback: "Server certificate can't be verified.") }
  /// General title for several error alerts
  public static var errorUnknownTitle: String { return Localizable.tr("Localizable", "_error_unknown_title", fallback: "Unknown error") }
  /// VPN credentials can't be loaded error
  public static var errorUserCredentialsExpired: String { return Localizable.tr("Localizable", "_error_user_credentials_expired", fallback: "User credentials have expired. Please sign in") }
  /// VPN credentials can't be loaded error
  public static var errorUserCredentialsMissing: String { return Localizable.tr("Localizable", "_error_user_credentials_missing", fallback: "User credentials are missing. Unable to sign in") }
  /// Human validation failed
  public static var errorUserFailedHumanValidation: String { return Localizable.tr("Localizable", "_error_user_failed_human_validation", fallback: "We have not been able to verify that you are human. Please try again or purchase a premium plan.") }
  /// VPN credentials can't be loaded error
  public static var errorVpnCredentialsMissing: String { return Localizable.tr("Localizable", "_error_vpn_credentials_missing", fallback: "VPN credentials are missing from the keychain") }
  /// VPN session is active error
  public static var errorVpnSessionIsActive: String { return Localizable.tr("Localizable", "_error_vpn_session_is_active", fallback: "Proton VPN session is active") }
  /// Description of the expand/collapse button used by accessibility Voice Over
  public static var expandListOfServers: String { return Localizable.tr("Localizable", "_expand_list_of_servers", fallback: "Expand list of servers") }
  /// MAC: is inserted into _free_trial_expired_title insteadof %@
  public static var expired: String { return Localizable.tr("Localizable", "_expired", fallback: "EXPIRED") }
  /// iOS: Table header in settings screen
  public static var extensions: String { return Localizable.tr("Localizable", "_extensions", fallback: "Extensions") }
  /// MacOS: connecting overlay
  public static var failed: String { return Localizable.tr("Localizable", "_failed", fallback: "failed") }
  /// Used for both profile description when fastest server option is selected and Plan speed description
  public static var fastest: String { return Localizable.tr("Localizable", "_fastest", fallback: "Fastest") }
  /// Profile create/change form
  public static var fastestAvailableServer: String { return Localizable.tr("Localizable", "_fastest_available_server", fallback: "Fastest available server") }
  /// iOS: Predefined profile with fastest connection
  public static var fastestConnection: String { return Localizable.tr("Localizable", "_fastest_connection", fallback: "Fastest") }
  /// Feature
  public static var feature: String { return Localizable.tr("Localizable", "_feature", fallback: "Feature") }
  /// iOS plan feature
  public static var featureConnections: String { return Localizable.tr("Localizable", "_feature_connections", fallback: "Simultaneous VPN connections") }
  /// Free servers
  public static var featureFreeServers: String { return Localizable.tr("Localizable", "_feature_free_servers", fallback: "Free servers") }
  /// Security and privacy for everyone. Free servers have no data limits, and we’ll never deliberately slow down your browsing speed.
  public static var featureFreeServersDescription: String { return Localizable.tr("Localizable", "_feature_free_servers_description", fallback: "Security and privacy for everyone. Free servers have no data limits, and we’ll never deliberately slow down your browsing speed.") }
  /// These servers give the best performance for BitTorrent and file sharing.
  public static var featureP2pDescription: String { return Localizable.tr("Localizable", "_feature_p2p_description", fallback: "These servers give the best performance for BitTorrent and file sharing.") }
  /// iOS plan feature
  public static var featureSecureCore: String { return Localizable.tr("Localizable", "_feature_secure_core", fallback: "Secure Core") }
  /// iOS plan feature
  public static var featureSecureStreaming: String { return Localizable.tr("Localizable", "_feature_secure_streaming", fallback: "Secure Streaming") }
  /// iOS plan feature
  public static var featureServerCount: String { return Localizable.tr("Localizable", "_feature_server_count", fallback: "Connect to servers in") }
  /// This technology allows Proton VPN to provide higher speed and security in difficult-to-serve countries.
  public static var featureSmartRoutingDescription: String { return Localizable.tr("Localizable", "_feature_smart_routing_description", fallback: "This technology allows Proton VPN to provide higher speed and security in difficult-to-serve countries.") }
  /// iOS plan feature
  public static var featureSpeed: String { return Localizable.tr("Localizable", "_feature_speed", fallback: "Speed") }
  /// Plus servers support streaming (Netflix, Disney+, etc) from anywhere in the world.
  public static var featureStreamingDescription: String { return Localizable.tr("Localizable", "_feature_streaming_description", fallback: "Plus servers support streaming (Netflix, Disney+, etc) from anywhere in the world.") }
  /// iOS plan feature
  public static var featureTor: String { return Localizable.tr("Localizable", "_feature_tor", fallback: "Tor over VPN") }
  /// Route your internet traffic through the Tor network. Slower, but more private.
  public static var featureTorDescription: String { return Localizable.tr("Localizable", "_feature_tor_description", fallback: "Route your internet traffic through the Tor network. Slower, but more private.") }
  /// Features
  public static var featuresTitle: String { return Localizable.tr("Localizable", "_features_title", fallback: "Features") }
  /// The version of Proton VPN application you are currently using is no longer supported. Please update to the latest version.
  public static var forceUpgradeMessage: String { return Localizable.tr("Localizable", "_force_upgrade_message", fallback: "The version of Proton VPN application you are currently using is no longer supported. Please update to the latest version.") }
  /// Application upgrade needed
  public static var forceUpgradeTitle: String { return Localizable.tr("Localizable", "_force_upgrade_title", fallback: "Application upgrade needed") }
  /// iOS: button in login screen
  public static var forgotPassword: String { return Localizable.tr("Localizable", "_forgot_password", fallback: "Forgot Password?") }
  /// MacOS: button in login screen
  public static var forgotUsername: String { return Localizable.tr("Localizable", "_forgot_username", fallback: "Forgot Username") }
  /// Used instead of price for free plans.
  public static var free: String { return Localizable.tr("Localizable", "_free", fallback: "Free") }
  /// Text on upsell banner in country list
  public static var freeBannerText: String { return Localizable.tr("Localizable", "_free_banner_text", fallback: "Get worldwide coverage with VPN Plus") }
  /// Account plan description
  public static var freeCountries: String { return Localizable.tr("Localizable", "_free_countries", fallback: "3 Countries") }
  /// Section header in search
  public static var freeServers: String { return Localizable.tr("Localizable", "_free_servers", fallback: "Free Servers") }
  /// %@ is always 'Proton VPN Plus' e.g. Upgrade to Proton VPN Plus and continue enjoying these features: I list of Plus plan-only features follows this text
  public static func freeTrialAboutToExpireDescription(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_free_trial_about_to_expire_description", String(describing: p1), fallback: "Upgrade to %@ and continue enjoying these features:")
  }
  /// MacOS: \Trial about to expire\ screen title
  public static var freeTrialAboutToExpireTitle: String { return Localizable.tr("Localizable", "_free_trial_about_to_expire_title", fallback: "Your free trial is about to expire!") }
  /// %@ is always 'Proton VPN Plus' e.g. Your account has been downgraded to Proton VPN Free.
  /// Here's what you will miss from Proton VPN Plus: A list of Plus plan-only features follows this text
  public static func freeTrialExpiredDescription(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_free_trial_expired_description", String(describing: p1), fallback: "Your account has been downgraded to Proton VPN Free.\nHere's what you will miss from %@:")
  }
  /// %@ is always 'EXPIRED' e.g. YOUR FREE TRIAL EXPIRED
  public static func freeTrialExpiredTitle(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_free_trial_expired_title", String(describing: p1), fallback: "Your free trial %@")
  }
  /// From Server:
  public static var fromServerTitle: String { return Localizable.tr("Localizable", "_from_server_title", fallback: "From Server:") }
  /// Gateways info modals text (both iOS and macOS)
  public static var gatewaysModalText: String { return Localizable.tr("Localizable", "_gateways_modal_text", fallback: "A VPN gateway is a secure connection that provides controlled access to your company's data and services through dedicated servers") }
  /// Gateways info modals title (both iOS and macOS)
  public static var gatewaysModalTitle: String { return Localizable.tr("Localizable", "_gateways_modal_title", fallback: "What's a gateway?") }
  /// MacOS: General tab in setting window
  public static var general: String { return Localizable.tr("Localizable", "_general", fallback: "General") }
  /// %@ is a plan name e.g. Get Plus Plan
  public static func getPlan(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_get_plan", String(describing: p1), fallback: "Get %@ Plan")
  }
  /// Suggest the user to upgrade account for new features
  public static var getPlusForFeature: String { return Localizable.tr("Localizable", "_get_plus_for_feature", fallback: "Get Proton VPN Plus to unlock this and other features.") }
  /// iOS: Button in email verification screen
  public static var getVerificationEmail: String { return Localizable.tr("Localizable", "_get_verification_email", fallback: "Get verification email") }
  /// iOS: Button in SMS verification screen
  public static var getVerificationSms: String { return Localizable.tr("Localizable", "_get_verification_sms", fallback: "Get verification SMS") }
  /// Button in several different alerts
  public static var gotIt: String { return Localizable.tr("Localizable", "_got_it", fallback: "Got it!") }
  /// Main app menu; User with \Proton VPN\ inside the same main menu as a name for item that opens help page.
  public static var help: String { return Localizable.tr("Localizable", "_help", fallback: "Help") }
  /// Show/hide password switch
  public static var hide: String { return Localizable.tr("Localizable", "_hide", fallback: "HIDE") }
  /// Value of speed in _speed
  public static var high: String { return Localizable.tr("Localizable", "_high", fallback: "High") }
  /// Value of speed in _speed
  public static var highest: String { return Localizable.tr("Localizable", "_highest", fallback: "Highest") }
  /// iOS: Home screen title, tab bar item title; MacOS: TabBar tab title;
  public static var home: String { return Localizable.tr("Localizable", "_home", fallback: "Home") }
  /// Tooltip text for the pin/unpin/remove actions in the recents list. [Redesign_2023]
  public static var homeRecentsOptionsButtonHelp: String { return Localizable.tr("Localizable", "_home_recents_options_button_help", fallback: "Actions") }
  /// Tooltip text presented on hover over one of the recent connections items. [Redesign_2023]
  public static var homeRecentsPlusServer: String { return Localizable.tr("Localizable", "_home_recents_plus_server", fallback: "Server available with VPN Plus") }
  /// The section of recent connections in the Home tab. [Redesign_2023]
  public static var homeRecentsRecentSection: String { return Localizable.tr("Localizable", "_home_recents_recent_section", fallback: "Recents") }
  /// Tooltip text presented on hover over one of the recent connections items. [Redesign_2023]
  public static var homeRecentsServerUnderMaintenance: String { return Localizable.tr("Localizable", "_home_recents_server_under_maintenance", fallback: "Server under maintenance") }
  /// Home tab in bottom menu [Redesign_2023]
  public static var homeTab: String { return Localizable.tr("Localizable", "_home_tab", fallback: "Home") }
  /// The hint that the screen reader will provide to voiceover users for the header in the home tab when the VPN is not connected to any server. [Redesign_2023]
  public static var homeUnprotectedAccessibilityHint: String { return Localizable.tr("Localizable", "_home_unprotected_accessibility_hint", fallback: "The VPN is disconnected. Connect to a server to securely browse the internet.") }
  /// The accessibility label given for the header at the top of the home tab when the VPN is not connected to any server. [Redesign_2023]
  public static func homeUnprotectedAccessibilityLabel(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_home_unprotected_accessibility_label", String(describing: p1), fallback: "You are browsing unprotected from %@.")
  }
  /// The header shown at the top of the application in the home tab when the VPN is not connected to any server. [Redesign_2023]
  public static var homeUnprotectedHeader: String { return Localizable.tr("Localizable", "_home_unprotected_header", fallback: "You are unprotected") }
  /// Button in Kill switch error alert
  public static var ignore: String { return Localizable.tr("Localizable", "_ignore", fallback: "Ignore") }
  /// iOS Settings -> Protocol: IKEv2 option
  public static var ikev2: String { return Localizable.tr("Localizable", "_ikev2", fallback: "IKEv2") }
  /// Information
  public static var informationTitle: String { return Localizable.tr("Localizable", "_information_title", fallback: "Information") }
  /// MacOS: connecting overlay
  public static var initializingConnection: String { return Localizable.tr("Localizable", "_initializing_connection", fallback: "Initializing Connection...") }
  /// It's been a while since you last used the Proton VPN app. Please log back in.
  public static var invalidRefreshTokenPleaseLogin: String { return Localizable.tr("Localizable", "_invalid_refresh_token_please_login", fallback: "It's been a while since you last used the Proton VPN app. Please log back in.") }
  /// iOS: Status view
  public static var ip: String { return Localizable.tr("Localizable", "_ip", fallback: "IP") }
  /// %@ is an IP address e.g. IP: 123.45.67.890
  public static func ipValue(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_ip_value", String(describing: p1), fallback: "IP: %@")
  }
  /// Your IP will not be exposed.
  public static var ipWillNotBeExposed: String { return Localizable.tr("Localizable", "_ip_will_not_be_exposed", fallback: "Your IP will not be exposed.") }
  /// MacOS: Settings -> Connection: name of field.
  public static var killSwitch: String { return Localizable.tr("Localizable", "_kill_switch", fallback: "Kill switch") }
  /// Disconnect notification
  public static var killSwitchBlockingConnection: String { return Localizable.tr("Localizable", "_kill_switch_blocking_connection", fallback: "Kill switch blocking all connections") }
  /// MacOS: killswitch blocking alert button
  public static var killSwitchDisable: String { return Localizable.tr("Localizable", "_kill_switch_disable", fallback: "Disable Kill switch") }
  /// iOS and macOS: Enable kill switch on badly-routed networks
  public static var killSwitchEnable: String { return Localizable.tr("Localizable", "_kill_switch_enable", fallback: "Enable Kill Switch") }
  /// MacOS: connection screen - this text is appended (together with _kill_switch_reconnection in case killswitch is enabled and app tries to reconnect
  public static var killSwitchReconnection: String { return Localizable.tr("Localizable", "_kill_switch_reconnection", fallback: "Your internet connection will resume as soon as Proton VPN reconnects to a server.\nTo use the internet without VPN and kill switch protection, cancel the reconnection to the server.") }
  /// MacOS: connection screen - thes part of _kill_switch_reconnection_header is bolded
  public static var killSwitchReconnectionBold1: String { return Localizable.tr("Localizable", "_kill_switch_reconnection_bold1", fallback: "without") }
  /// MacOS: connection screen - thes part of _kill_switch_reconnection_header is bolded
  public static var killSwitchReconnectionBold2: String { return Localizable.tr("Localizable", "_kill_switch_reconnection_bold2", fallback: "Kill switch protection") }
  /// MacOS: connection screen - cancel button
  public static var killSwitchReconnectionCancel: String { return Localizable.tr("Localizable", "_kill_switch_reconnection_cancel", fallback: "Cancel reconnection") }
  /// MacOS: connection screen - this text is appended (together with _kill_switch_reconnection in case killswitch is enabled and app tries to reconnect
  public static var killSwitchReconnectionHeader: String { return Localizable.tr("Localizable", "_kill_switch_reconnection_header", fallback: "Kill switch is protecting your IP") }
  /// MacOS: Settings -> Connection. Kill switch functionality description.
  public static var killSwitchTooltip: String { return Localizable.tr("Localizable", "_kill_switch_tooltip", fallback: "Blocks all network traffic when VPN tunnel is lost.") }
  /// MacOS: link in login screen
  public static var learnMore: String { return Localizable.tr("Localizable", "_learn_more", fallback: "Learn more") }
  /// MacOS: SecureCore warning alert when users plan has to be upgraded
  public static var learnMoreAboutSecureCore: String { return Localizable.tr("Localizable", "_learn_more_about_secure_core", fallback: "Learn more about Secure Core") }
  /// Display less information
  public static var lessInfo: String { return Localizable.tr("Localizable", "_less_info", fallback: "Less info") }
  /// Shown when VPN is connected but not yet usable because not all the required data is yet set up
  public static var loadingConnectionInfo: String { return Localizable.tr("Localizable", "_loading_connection_info", fallback: "Loading connection info") }
  /// Shown when VPN is connected but not yet usable because not all the required data is yet set up
  public static func loadingConnectionInfoFor(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_loading_connection_info_for", String(describing: p1), fallback: "Loading connection info for %@")
  }
  /// Slogan text under the logo in may places in iOS and MacOS apps
  public static var loadingScreenSlogan: String { return Localizable.tr("Localizable", "_loading_screen_slogan", fallback: "Secure Internet Anywhere") }
  /// You are not allowed to connect to the server. Choose a different server or upgrade your plan.
  public static var localAgentPolicyViolationErrorMessage: String { return Localizable.tr("Localizable", "_local_agent_policy_violation_error_message", fallback: "You are not allowed to connect to the server. Choose a different server or upgrade your plan.") }
  /// Policy violation
  public static var localAgentPolicyViolationErrorTitle: String { return Localizable.tr("Localizable", "_local_agent_policy_violation_error_title", fallback: "Policy violation") }
  /// An error occured on the server. Please connect to another server.
  public static var localAgentServerErrorMessage: String { return Localizable.tr("Localizable", "_local_agent_server_error_message", fallback: "An error occured on the server. Please connect to another server.") }
  /// Server error
  public static var localAgentServerErrorTitle: String { return Localizable.tr("Localizable", "_local_agent_server_error_title", fallback: "Server error") }
  /// iOS status view
  public static var location: String { return Localizable.tr("Localizable", "_location", fallback: "Location") }
  /// All locations
  public static var locationsAll: String { return Localizable.tr("Localizable", "_locations_all", fallback: "All locations") }
  /// Free locations
  public static var locationsFree: String { return Localizable.tr("Localizable", "_locations_free", fallback: "Free locations") }
  /// Gateways
  public static var locationsGateways: String { return Localizable.tr("Localizable", "_locations_gateways", fallback: "Gateways") }
  /// Plus locations
  public static var locationsPlus: String { return Localizable.tr("Localizable", "_locations_plus", fallback: "Plus locations") }
  /// iOS: Login button in several places
  public static var logIn: String { return Localizable.tr("Localizable", "_log_in", fallback: "Sign in") }
  /// iOS widget: text for not-logged-in user
  public static var logInToUseWidget: String { return Localizable.tr("Localizable", "_log_in_to_use_widget", fallback: "Please sign in to get started") }
  /// iOS: button in settings screen
  public static var logOut: String { return Localizable.tr("Localizable", "_log_out", fallback: "Sign out") }
  /// iOS: Logout alert
  public static var logOutWarning: String { return Localizable.tr("Localizable", "_log_out_warning", fallback: "Signing out will end your VPN session.") }
  /// MacOS: Logout alert
  public static var logOutWarningLong: String { return Localizable.tr("Localizable", "_log_out_warning_long", fallback: "Signing out of the application will disconnect the active VPN connection. Do you want to continue?") }
  /// MacOS: Login button
  public static var login: String { return Localizable.tr("Localizable", "_login", fallback: "Sign in") }
  /// iOS logs screen title
  public static var logs: String { return Localizable.tr("Localizable", "_logs", fallback: "Logs") }
  /// Mac: neagent help screen
  public static var macPassword: String { return Localizable.tr("Localizable", "_mac_password", fallback: "Mac password") }
  /// Server status in many places in iOS and MacOS apps
  public static var maintenance: String { return Localizable.tr("Localizable", "_maintenance", fallback: "Maintenance") }
  /// Reconnecting you to the fastest available server.
  public static var maintenanceOnServerDetectedDescription: String { return Localizable.tr("Localizable", "_maintenance_on_server_detected_description", fallback: "Reconnecting you to the fastest available server.") }
  /// The server you were connected to is on maintenance
  public static var maintenanceOnServerDetectedSubtitle: String { return Localizable.tr("Localizable", "_maintenance_on_server_detected_subtitle", fallback: "The server you were connected to is on maintenance") }
  /// The VPN server is on maintenance
  public static var maintenanceOnServerDetectedTitle: String { return Localizable.tr("Localizable", "_maintenance_on_server_detected_title", fallback: "The VPN server is on maintenance") }
  /// Profile create/change form
  public static var makeDefaultProfile: String { return Localizable.tr("Localizable", "_make_default_profile", fallback: "Make Default Profile") }
  /// MacOS: button in profiles tab in main window
  public static var manageProfiles: String { return Localizable.tr("Localizable", "_manage_profiles", fallback: "Manage Profiles") }
  /// MacOS: Settings -> Account. Button leading to web interface.
  public static var manageSubscription: String { return Localizable.tr("Localizable", "_manage_subscription", fallback: "Manage Subscription") }
  /// Manage your subscription in the web dashboard
  public static var manageSubscriptionOnWeb: String { return Localizable.tr("Localizable", "_manage_subscription_on_web", fallback: "Manage your subscription in the web dashboard") }
  /// iOS: Map screen title and tabbar item
  public static var map: String { return Localizable.tr("Localizable", "_map", fallback: "Map") }
  /// MacOS: Map view toggle button accessibility label (used by screen readers
  public static var mapHide: String { return Localizable.tr("Localizable", "_map_hide", fallback: "Hide map") }
  /// MacOS: Map view toggle button accessibility label (used by screen readers
  public static var mapShow: String { return Localizable.tr("Localizable", "_map_show", fallback: "Show map") }
  /// Please disconnect another device to connect to this one.
  public static var maximumDeviceReachedDescription: String { return Localizable.tr("Localizable", "_maximum_device_reached_description", fallback: "Please disconnect another device to connect to this one.") }
  /// You have reached your maximum device limit
  public static var maximumDeviceTitle: String { return Localizable.tr("Localizable", "_maximum_device_title", fallback: "You have reached your maximum device limit") }
  /// Cancel button in trial modals used in both iOS and MacOS
  public static var maybeLater: String { return Localizable.tr("Localizable", "_maybe_later", fallback: "Maybe Later") }
  /// Value of speed in _speed
  public static var medium: String { return Localizable.tr("Localizable", "_medium", fallback: "Medium") }
  /// Main mac app menu item
  public static var menuAbout: String { return Localizable.tr("Localizable", "_menu_about", fallback: "About Proton VPN") }
  /// Main mac app menu item
  public static var menuCheckUpdates: String { return Localizable.tr("Localizable", "_menu_check_updates", fallback: "Check for Updates...") }
  /// Main mac app menu item
  public static var menuHideOthers: String { return Localizable.tr("Localizable", "_menu_hide_others", fallback: "Hide Others") }
  /// Main mac app menu item
  public static var menuHideSelf: String { return Localizable.tr("Localizable", "_menu_hide_self", fallback: "Hide Proton VPN") }
  /// Main mac app menu item
  public static var menuLogout: String { return Localizable.tr("Localizable", "_menu_logout", fallback: "Sign out") }
  /// Main mac app menu item
  public static var menuMinimize: String { return Localizable.tr("Localizable", "_menu_minimize", fallback: "Minimize") }
  /// Main mac app menu item
  public static var menuPreferences: String { return Localizable.tr("Localizable", "_menu_preferences", fallback: "Preferences") }
  /// Main mac app menu item
  public static var menuQuit: String { return Localizable.tr("Localizable", "_menu_quit", fallback: "Quit Proton VPN") }
  /// Main mac app menu item
  public static var menuShowAll: String { return Localizable.tr("Localizable", "_menu_show_all", fallback: "Show All") }
  /// Main mac app menu item
  public static var menuWindow: String { return Localizable.tr("Localizable", "_menu_window", fallback: "Window") }
  /// Title for alert shown when enabling Moderate NAT requires reconnection
  public static var moderateNatChangeTitle: String { return Localizable.tr("Localizable", "_moderate_nat_change_title", fallback: "Enable Moderate NAT") }
  /// Title for alert shown when enabling Moderate NAT requires reconnection
  public static var moderateNatEnableTitle: String { return Localizable.tr("Localizable", "_moderate_nat_enable_title", fallback: "Enable Moderate NAT") }
  /// Explanation for the Moderate NAT feature shown next to the feature in Settings
  public static var moderateNatExplanation: String { return Localizable.tr("Localizable", "_moderate_nat_explanation", fallback: "Moderate NAT disables randomization of local address mapping. This can slightly reduce your security, but allows peer-to-peer applications such as online games to establish direct connections. \nLearn more") }
  /// Link at the end of Moderate NAT feature explanation. Must match the explanation value
  public static var moderateNatExplanationLink: String { return Localizable.tr("Localizable", "_moderate_nat_explanation_link", fallback: "Learn more") }
  /// Moderate NAT feature title in Settings
  public static var moderateNatTitle: String { return Localizable.tr("Localizable", "_moderate_nat_title", fallback: "Moderate NAT") }
  /// Display more information
  public static var moreInfo: String { return Localizable.tr("Localizable", "_more_info", fallback: "Learn more") }
  /// Label in Plan information
  public static var mostPopular: String { return Localizable.tr("Localizable", "_most_popular", fallback: "Most popular") }
  /// Mac: Used in several Trial screens
  public static var multipleCountries: String { return Localizable.tr("Localizable", "_multiple_countries", fallback: "Multiple countries") }
  /// MacOS: \Trial about to expire\ screen
  public static var multipleServersDescription: String { return Localizable.tr("Localizable", "_multiple_servers_description", fallback: "Hundreds of servers\naround the world") }
  /// MacOS: \Trial about to expire\ screen
  public static var multipleServersTitle: String { return Localizable.tr("Localizable", "_multiple_servers_title", fallback: "Multiple Servers") }
  /// iOS: table header section in profiles screen
  public static var myProfiles: String { return Localizable.tr("Localizable", "_my_profiles", fallback: "My Profiles") }
  /// Profile create/change form
  public static var name: String { return Localizable.tr("Localizable", "_name", fallback: "Name") }
  /// Network error
  public static var neCouldntReachServer: String { return Localizable.tr("Localizable", "_ne_couldnt_reach_server", fallback: "We could not reach Proton servers") }
  /// Network error
  public static var neNetworkConnectionLost: String { return Localizable.tr("Localizable", "_ne_network_connection_lost", fallback: "Network connection lost") }
  /// Network error
  public static var neNotConnectedToTheInternet: String { return Localizable.tr("Localizable", "_ne_not_connected_to_the_internet", fallback: "Not connected to the internet") }
  /// Network error
  public static var neRequestTimedOut: String { return Localizable.tr("Localizable", "_ne_request_timed_out", fallback: "Network request timed out") }
  /// Button on alert after a problem with internet connection
  public static var neTroubleshoot: String { return Localizable.tr("Localizable", "_ne_troubleshoot", fallback: "Troubleshoot") }
  /// Network error
  public static var neUnableToConnectToHost: String { return Localizable.tr("Localizable", "_ne_unable_to_connect_to_host", fallback: "Service unreachable") }
  /// Mac: neagent help screen name of the Always Allow button the user needs to press in the macOS system dialog asking for account password
  public static var neagentAlwaysAllow: String { return Localizable.tr("Localizable", "_neagent_always_allow", fallback: "Always Allow") }
  /// Mac: neagent help screen. The numbers refer to a text field and button in an image displayed above this text. Final string with filled in variables looks like this: "You may be asked to provide your computer account password
  /// to connect to the Proton VPN service. If this request appears,
  /// enter your Mac password (1) and click ‘Always Allow’ (2)."
  public static func neagentDescription(_ p1: Any, _ p2: Any, _ p3: Any, _ p4: Any, _ p5: Any) -> String {
    return Localizable.tr("Localizable", "_neagent_description", String(describing: p1), String(describing: p2), String(describing: p3), String(describing: p4), String(describing: p5), fallback: "You may be asked to provide your %@\nto connect to the Proton VPN service. If this request appears,\nenter your %@ %@ and click ‘%@’ %@.")
  }
  /// Mac: neagent help screen
  public static var neagentFirstStep: String { return Localizable.tr("Localizable", "_neagent_first_step", fallback: "(1)") }
  /// Mac: neagent help screen
  public static var neagentPassword: String { return Localizable.tr("Localizable", "_neagent_password", fallback: "computer account password") }
  /// Mac: neagent help screen
  public static var neagentSecondStep: String { return Localizable.tr("Localizable", "_neagent_second_step", fallback: "(2)") }
  /// MacOS: button in login screen
  public static var needHelp: String { return Localizable.tr("Localizable", "_need_help", fallback: "Need Help?") }
  /// Enable anyway
  public static var neksT2Connect: String { return Localizable.tr("Localizable", "_neks_t2_connect", fallback: "Enable anyway") }
  /// The use of kill switch is unstable on this device.
  /// 
  /// Your device has a T2 Security Chip, which can result in system stability issues if the kill switch functionality of macOS is used by Proton VPN.
  public static var neksT2Description: String { return Localizable.tr("Localizable", "_neks_t2_description", fallback: "The use of kill switch is unstable on this device.\n\nYour device has a T2 Security Chip, which can result in system stability issues if the kill switch functionality of macOS is used by Proton VPN.") }
  /// Hyperlink to the "T2 Security Chip" page on Apple's website. String must also appear in the `_neks_t2_description' localized string.
  public static var neksT2Hyperlink: String { return Localizable.tr("Localizable", "_neks_t2_hyperlink", fallback: "T2 Security Chip") }
  /// NetworkExtension + KillSwitch on T2 Macs
  public static var neksT2Title: String { return Localizable.tr("Localizable", "_neks_t2_title", fallback: "Kill switch Stability Warning") }
  /// Your connection will be restarted to change the NetShield mode.
  public static var netshieldAlertReconnectDescriptionOff: String { return Localizable.tr("Localizable", "_netshield_alert_reconnect_description_off", fallback: "Your connection will be restarted to change the NetShield mode.") }
  /// Your connection will be restarted to change the NetShield mode.
  /// Note: If some sites don't load, try disabling NetShield.
  public static var netshieldAlertReconnectDescriptionOn: String { return Localizable.tr("Localizable", "_netshield_alert_reconnect_description_on", fallback: "Your connection will be restarted to change the NetShield mode.\nNote: If some sites don't load, try disabling NetShield.") }
  /// NetShield increases your privacy by blocking advertisements and trackers.
  public static var netshieldAlertUpgradeDescription: String { return Localizable.tr("Localizable", "_netshield_alert_upgrade_description", fallback: "NetShield increases your privacy by blocking advertisements and trackers.") }
  /// Settings -> Netshield, Status -> NetShield: Netshield Upsell cell subtitle
  public static var netshieldBusinessUpsellSubtitle: String { return Localizable.tr("Localizable", "_netshield_business_upsell_subtitle", fallback: "When you upgrade to VPN Business") }
  /// Settings -> Netshield, Status -> NetShield: Netshield Upsell cell title
  public static var netshieldBusinessUpsellTitle: String { return Localizable.tr("Localizable", "_netshield_business_upsell_title", fallback: "Block ads with NetShield") }
  /// Settings -> Netshield, Status -> NetShield: Long description of the feature, displayed below netshield levels for premium users. Contains a link to https://protonvpn.com/support/netshield
  public static var netshieldFeatureDescription: String { return Localizable.tr("Localizable", "_netshield_feature_description", fallback: "Protect yourself from ads, malware, and trackers on websites and apps. If websites don't load, try disabling NetShield.\nLearn more") }
  /// Link with more info in the NetShield Feature description
  public static var netshieldFeatureDescriptionAltLink: String { return Localizable.tr("Localizable", "_netshield_feature_description_alt_link", fallback: "Learn more") }
  /// Settings -> Netshield: Block malware
  public static var netshieldLevel1: String { return Localizable.tr("Localizable", "_netshield_level1", fallback: "Block malware") }
  /// Settings -> Netshield: Block malware, ads, trackers
  public static var netshieldLevel2: String { return Localizable.tr("Localizable", "_netshield_level2", fallback: "Block malware, ads, & trackers") }
  /// Settings -> Netshield, Status -> NetShield: Off
  public static var netshieldOff: String { return Localizable.tr("Localizable", "_netshield_off", fallback: "Off") }
  /// Status -> Netshield: On
  public static var netshieldOn: String { return Localizable.tr("Localizable", "_netshield_on", fallback: "On") }
  /// Netshield section title in iOS connection screen
  public static var netshieldSectionTitle: String { return Localizable.tr("Localizable", "_netshield_section_title", fallback: "Malware & Ads Blocker") }
  /// Plural format key: "%#@VARIABLE@"
  public static func netshieldStatsAdsBlocked(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "_netshield_stats_ads_blocked", p1, fallback: "Plural format key: \"%#@VARIABLE@\"")
  }
  /// The count of trackers/ads blocked in sextillions
  public static func netshieldStatsBlockedE(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_netshield_stats_blocked_E", String(describing: p1), fallback: "%@ E")
  }
  /// The count of trackers/ads blocked in billions
  public static func netshieldStatsBlockedG(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_netshield_stats_blocked_G", String(describing: p1), fallback: "%@ G")
  }
  /// The count of trackers/ads blocked in thousands
  public static func netshieldStatsBlockedK(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_netshield_stats_blocked_K", String(describing: p1), fallback: "%@ K")
  }
  /// The count of trackers/ads blocked in millions
  public static func netshieldStatsBlockedM(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_netshield_stats_blocked_M", String(describing: p1), fallback: "%@ M")
  }
  /// The count of trackers/ads blocked in quadrillions
  public static func netshieldStatsBlockedP(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_netshield_stats_blocked_P", String(describing: p1), fallback: "%@ P")
  }
  /// The count of trackers/ads blocked in trillions
  public static func netshieldStatsBlockedT(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_netshield_stats_blocked_T", String(describing: p1), fallback: "%@ T")
  }
  /// Data
  /// saved
  public static var netshieldStatsDataSaved: String { return Localizable.tr("Localizable", "_netshield_stats_data_saved", fallback: "Data\nsaved") }
  /// Plural format key: "%#@VARIABLE@"
  public static func netshieldStatsTrackersStopped(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "_netshield_stats_trackers_stopped", p1, fallback: "Plural format key: \"%#@VARIABLE@\"")
  }
  /// Settings -> Netshield: name of field.
  public static var netshieldTitle: String { return Localizable.tr("Localizable", "_netshield_title", fallback: "NetShield") }
  /// Block advertisements, trackers and malware
  public static var netshieldTitleTooltip: String { return Localizable.tr("Localizable", "_netshield_title_tooltip", fallback: "Block advertisements, trackers and malware") }
  /// Settings -> Netshield, Status -> NetShield: Netshield Upsell cell subtitle
  public static var netshieldUpsellSubtitle: String { return Localizable.tr("Localizable", "_netshield_upsell_subtitle", fallback: "Block ads, trackers and malware on websites and apps") }
  /// Settings -> Netshield, Status -> NetShield: Netshield Upsell cell title
  public static var netshieldUpsellTitle: String { return Localizable.tr("Localizable", "_netshield_upsell_title", fallback: "Browse ad-free with NetShield") }
  /// iOS: quick connect widget
  public static var networkUnreachable: String { return Localizable.tr("Localizable", "_network_unreachable", fallback: "Network Unreachable") }
  /// Title of the screen with news and offers.
  public static var newsTitle: String { return Localizable.tr("Localizable", "_news_title", fallback: "News") }
  /// Text used when no active server information is available
  public static var noDescriptionAvailable: String { return Localizable.tr("Localizable", "_no_description_available", fallback: "No description available") }
  /// There are currently no servers to show here.
  public static var noServersToShow: String { return Localizable.tr("Localizable", "_no_servers_to_show", fallback: "There are currently no servers to show here.") }
  /// No thanks
  public static var noThanks: String { return Localizable.tr("Localizable", "_no_thanks", fallback: "No thanks") }
  /// Title for alert shown when enabling Non-standard ports requires reconnection
  public static var nonStandardPortsChangeTitle: String { return Localizable.tr("Localizable", "_non_standard_ports_change_title", fallback: "Enable Non-standard ports") }
  /// Explanation for the Non-standard ports feature shown next to the feature in Settings
  public static var nonStandardPortsExplanation: String { return Localizable.tr("Localizable", "_non_standard_ports_explanation", fallback: "Use Proton VPN for any special need by allowing traffic to non-standard ports through the VPN network. \nLearn more") }
  /// Link at the end of Non-standard ports feature explanation. Must match the explanation value
  public static var nonStandardPortsExplanationLink: String { return Localizable.tr("Localizable", "_non_standard_ports_explanation_link", fallback: "Learn more") }
  /// Non-standard ports feature title in Settings
  public static var nonStandardPortsTitle: String { return Localizable.tr("Localizable", "_non_standard_ports_title", fallback: "Non-standard ports") }
  /// iOS: connection bar; Main mac app menu item;
  public static var notConnected: String { return Localizable.tr("Localizable", "_not_connected", fallback: "Not Connected") }
  /// Title in no internet alert
  public static var notConnectedToTheInternet: String { return Localizable.tr("Localizable", "_not_connected_to_the_internet", fallback: "Unable to establish VPN connection. You are not connected to the internet.") }
  /// Not now
  public static var notNow: String { return Localizable.tr("Localizable", "_not_now", fallback: "Not now") }
  /// Text appears in the welcome offer banner. Indicates the time left before offer expires. Examples: "Ending in 34 minutes", "Ending in 4 days", "Ending in 1 hour"
  public static func offerEnding(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_offer_ending_", String(describing: p1), fallback: "Ending %@")
  }
  /// Common word
  public static var ok: String { return Localizable.tr("Localizable", "_ok", fallback: "OK") }
  /// MacOS: voice over indication for a country or server on maintenance
  public static var onMaintenance: String { return Localizable.tr("Localizable", "_on_maintenance", fallback: "On maintenance") }
  /// Telemetry label in the onboarding screen for mac next to a toggle
  public static var onboardingMacCrashReports: String { return Localizable.tr("Localizable", "_onboarding_mac_crash_reports", fallback: "Share anonymous crash reports. This helps us fix bugs, detect firewalls, and avoid VPN blocks.") }
  /// Telemetry label in the onboarding screen for mac next to a toggle
  public static var onboardingMacUsageStats: String { return Localizable.tr("Localizable", "_onboarding_mac_usage_stats", fallback: "Share anonymous usage statistics. This helps us overcome VPN blocks and improve app performance.") }
  /// Main mac app menu item
  public static var openAppToLogIn: String { return Localizable.tr("Localizable", "_open_app_to_log_in", fallback: "Show Proton VPN to sign in...") }
  /// iOS Settings: OpenVPN logs row
  public static var openVpnLogs: String { return Localizable.tr("Localizable", "_open_vpn_logs", fallback: "OpenVPN Logs") }
  /// OpenVPN
  public static var openvpn: String { return Localizable.tr("Localizable", "_openvpn", fallback: "OpenVPN") }
  /// MacOS menu item; MacOS Profiles tab title;
  public static var overview: String { return Localizable.tr("Localizable", "_overview", fallback: "Overview") }
  /// MacOS profile form: feature selection value; iOS: country.server description in countries list;
  public static var p2p: String { return Localizable.tr("Localizable", "_p2p", fallback: "P2P") }
  /// Description shown together with server info icon
  public static var p2pDescription: String { return Localizable.tr("Localizable", "_p2p_description", fallback: "Supports P2P traffic") }
  /// Your connection has been disabled because you are using a server that does not support peer-to-peer (P2P) traffic. P2P is not supported on free servers or servers that are numbered 100 or greater.
  public static var p2pDetectedPopupBody: String { return Localizable.tr("Localizable", "_p2p_detected_popup_body", fallback: "Your connection has been disabled because you are using a server that does not support peer-to-peer (P2P) traffic. P2P is not supported on free servers or servers that are numbered 100 or greater.") }
  /// P2P traffic is not permitted on this server
  public static var p2pDetectedPopupTitle: String { return Localizable.tr("Localizable", "_p2p_detected_popup_title", fallback: "P2P traffic is not permitted on this server") }
  /// Your connection has been automatically rerouted through another server because some servers do not support P2P traffic. This may reduce your connection speed. Please use servers with the P2P label to avoid rerouting.
  public static var p2pForwardedPopupBody: String { return Localizable.tr("Localizable", "_p2p_forwarded_popup_body", fallback: "Your connection has been automatically rerouted through another server because some servers do not support P2P traffic. This may reduce your connection speed. Please use servers with the P2P label to avoid rerouting.") }
  /// Your connection has been automatically rerouted through another server because certain servers do not support P2P traffic. This may reduce your connection speed. Please use servers with the
  public static var p2pForwardedPopupBodyP1: String { return Localizable.tr("Localizable", "_p2p_forwarded_popup_body_p1", fallback: "Your connection has been automatically rerouted through another server because certain servers do not support P2P traffic. This may reduce your connection speed. Please use servers with the") }
  /// icon to avoid traffic rerouting.
  public static var p2pForwardedPopupBodyP2: String { return Localizable.tr("Localizable", "_p2p_forwarded_popup_body_p2", fallback: "icon to avoid traffic rerouting.") }
  /// Connection rerouted
  public static var p2pForwardedPopupTitle: String { return Localizable.tr("Localizable", "_p2p_forwarded_popup_title", fallback: "Connection rerouted") }
  /// MacOS: label in server info view (shown after click on Info icon in countries list
  public static var p2pServer: String { return Localizable.tr("Localizable", "_p2p_server", fallback: "P2P Server") }
  /// MacOS: Used ir trial welcome and trial expired screens
  public static var p2pServers: String { return Localizable.tr("Localizable", "_p2p_servers", fallback: "P2P servers") }
  /// P2P/BitTorrent
  public static var p2pTitle: String { return Localizable.tr("Localizable", "_p2p_title", fallback: "P2P/BitTorrent") }
  /// Used in sign-in, sign-up
  public static var password: String { return Localizable.tr("Localizable", "_password", fallback: "Password") }
  /// Sign-up form
  public static var passwordConfirm: String { return Localizable.tr("Localizable", "_password_confirm", fallback: "Confirm password") }
  /// Per year. Appended to plan price.
  public static var perYearShort: String { return Localizable.tr("Localizable", "_per_year_short", fallback: "/ yr") }
  /// Servers with high load are slower than servers with low load.
  public static var performanceLoadDescription: String { return Localizable.tr("Localizable", "_performance_load_description", fallback: "Servers with high load are slower than servers with low load.") }
  /// High
  public static var performanceLoadHigh: String { return Localizable.tr("Localizable", "_performance_load_high", fallback: "High") }
  /// Low
  public static var performanceLoadLow: String { return Localizable.tr("Localizable", "_performance_load_low", fallback: "Low") }
  /// Medium
  public static var performanceLoadMedium: String { return Localizable.tr("Localizable", "_performance_load_medium", fallback: "Medium") }
  /// Performance
  public static var performanceTitle: String { return Localizable.tr("Localizable", "_performance_title", fallback: "Performance") }
  /// iOS: placeholder in phone verification screen
  public static var phoneCountryCodePlaceholder: String { return Localizable.tr("Localizable", "_phone_country_code_placeholder", fallback: "Code") }
  /// iOS: placeholder in phone verification screen
  public static var phoneNumberPlaceholder: String { return Localizable.tr("Localizable", "_phone_number_placeholder", fallback: "Enter phone number") }
  /// MacOS: SecureCore warning alert when users plan has to be upgraded
  public static var planDoesNotIncludeSecureCore: String { return Localizable.tr("Localizable", "_plan_does_not_include_secure_core", fallback: "Your plan doesn't include Secure Core feature.") }
  /// Fastest speed
  public static var planSpeedFastest: String { return Localizable.tr("Localizable", "_plan_speed_fastest", fallback: "Fastest speed") }
  /// Plan speed
  public static var planSpeedHigh: String { return Localizable.tr("Localizable", "_plan_speed_high", fallback: "High speed") }
  /// Plan speed
  public static var planSpeedMedium: String { return Localizable.tr("Localizable", "_plan_speed_medium", fallback: "Medium speed") }
  /// Plural format key: "%#@VARIABLE@"
  public static func plansConnections(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "_plans_connections", p1, fallback: "Plural format key: \"%#@VARIABLE@\"")
  }
  /// Text description in plan selection screen
  public static var plansFooter: String { return Localizable.tr("Localizable", "_plans_footer", fallback: "Upon confirming your purchase of a paid plan, your iTunes account will be charged the amount displayed, which includes taxes and additional platform fees (which are not charged by Proton directly). After making the purchase, you will automatically be upgraded to the selected plan for a 1 year period, after which time you can renew or cancel, either online or through our iOS app.") }
  /// Plus word that is put inside `enjoyForFree` translation instead of %@
  public static var plus: String { return Localizable.tr("Localizable", "_plus", fallback: "Plus") }
  /// Features of account plan
  public static var plusPlanFeatures: String { return Localizable.tr("Localizable", "_plus_plan_features", fallback: "Plus Servers\nSecure Core\nTor Servers") }
  /// Section header in search
  public static var plusServers: String { return Localizable.tr("Localizable", "_plus_servers", fallback: "Plus Servers") }
  /// MacOS: Settings screen title
  public static var preferences: String { return Localizable.tr("Localizable", "_preferences", fallback: "Preferences") }
  /// Description shown together with server info icon
  public static var premiumDescription: String { return Localizable.tr("Localizable", "_premium_description", fallback: "Premium server") }
  /// MacOS: label in server info view (shown after click on Info icon in countries list
  public static var premiumServer: String { return Localizable.tr("Localizable", "_premium_server", fallback: "Premium Server") }
  /// MacOS: connecting overlay
  public static var preparingConnection: String { return Localizable.tr("Localizable", "_preparing_connection", fallback: "Checking server availability") }
  /// iOS: link inside text under sign-up form
  public static var privacyPolicy: String { return Localizable.tr("Localizable", "_privacy_policy", fallback: "Privacy Policy") }
  /// MacOS Profiles Overview: Table column header
  public static var profile: String { return Localizable.tr("Localizable", "_profile", fallback: "Profile") }
  /// iOS: success message after profile is saved
  public static var profileCreatedSuccessfully: String { return Localizable.tr("Localizable", "_profile_created_successfully", fallback: "New Profile saved") }
  /// iOS: failure message after profile is saved
  public static var profileCreationFailed: String { return Localizable.tr("Localizable", "_profile_creation_failed", fallback: "Profile could not be created") }
  /// iOS: Success message on profile deletion
  public static var profileDeletedSuccessfully: String { return Localizable.tr("Localizable", "_profile_deleted_successfully", fallback: "Profile has been deleted") }
  /// iOS: Error message if profile can't be deleted
  public static var profileDeletionFailed: String { return Localizable.tr("Localizable", "_profile_deletion_failed", fallback: "Profile could not be deleted") }
  /// iOS: success message after profile is saved
  public static var profileEditedSuccessfully: String { return Localizable.tr("Localizable", "_profile_edited_successfully", fallback: "Profile updated") }
  /// Error in profile create/change form
  public static var profileNameIsRequired: String { return Localizable.tr("Localizable", "_profile_name_is_required", fallback: "Please enter a name") }
  /// Error in profile create/change form
  public static var profileNameIsTooLong: String { return Localizable.tr("Localizable", "_profile_name_is_too_long", fallback: "Maximum profile name length is 25 characters") }
  /// Profile with same name already exists
  public static var profileNameNeedsToBeUnique: String { return Localizable.tr("Localizable", "_profile_name_needs_to_be_unique", fallback: "Profile with same name already exists") }
  /// Profile create/change form
  public static var profileSettings: String { return Localizable.tr("Localizable", "_profile_settings", fallback: "Profile settings") }
  /// MacOS: menu item, profiles window main header, sidebar tab title; iOS: Profiles screen title and tabbar item title;
  public static var profiles: String { return Localizable.tr("Localizable", "_profiles", fallback: "Profiles") }
  /// MacOS: profiles window title
  public static var profilesOverview: String { return Localizable.tr("Localizable", "_profiles_overview", fallback: "Profiles Overview") }
  /// Error message indicating that one of the device's interfaces to the local network is poorly configured, which can result in traffic leaks if Kill Switch is not enabled. %@1 is the name of the bad network interface, %@2 is the IP and network prefix assigned to that interface in CIDR notation (an example would be 10.0.1.3/24).
  public static func promptKillSwitchDueToBadInterfaceIpRange(_ p1: Any, _ p2: Any) -> String {
    return Localizable.tr("Localizable", "_prompt_kill_switch_due_to_bad_interface_ip_range", String(describing: p1), String(describing: p2), fallback: "Your local network might be unsafe (the interface '%@' has the IP and prefix '%@'). Your data may be sent unencrypted over the local network. Enabling Kill Switch will block this traffic. Connections to local peripherals will be interrupted.")
  }
  /// Protocol
  public static var `protocol`: String { return Localizable.tr("Localizable", "_protocol", fallback: "Protocol") }
  /// %@ is an IP address e.g. Public IP: 123.45.67.890
  public static func publicIp(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_public_ip", String(describing: p1), fallback: "Public IP: %@")
  }
  /// Several places in both iOS and Mac apps
  public static var quickConnect: String { return Localizable.tr("Localizable", "_quick_connect", fallback: "Quick Connect") }
  /// MacOS: Settings -> Connection: description.
  public static var quickConnectTooltip: String { return Localizable.tr("Localizable", "_quick_connect_tooltip", fallback: "Quick Connect button will connect you to the selected profile") }
  /// Get Plus
  public static var quickSettingsGetPlus: String { return Localizable.tr("Localizable", "_quick_settings_get_plus", fallback: "Get Plus") }
  /// Disables internet if the VPN connection drops to prevent accidental IP leak.
  public static var quickSettingsKillSwitchDescription: String { return Localizable.tr("Localizable", "_quick_settings_killSwitch_description", fallback: "Disables internet if the VPN connection drops to prevent accidental IP leak.") }
  /// If you can't connect to devices on your local network, try disabling kill switch.
  public static var quickSettingsKillSwitchNote: String { return Localizable.tr("Localizable", "_quick_settings_killSwitch_note", fallback: "If you can't connect to devices on your local network, try disabling kill switch.") }
  /// Browse the internet without ads and malware.
  public static var quickSettingsNetShieldDescription: String { return Localizable.tr("Localizable", "_quick_settings_netShield_description", fallback: "Browse the internet without ads and malware.") }
  /// If websites don’t load, try disabling NetShield
  public static var quickSettingsNetShieldNote: String { return Localizable.tr("Localizable", "_quick_settings_netShield_note", fallback: "If websites don’t load, try disabling NetShield") }
  /// Block malware only
  public static var quickSettingsNetshieldOptionLevel1: String { return Localizable.tr("Localizable", "_quick_settings_netshield_option_level1", fallback: "Block malware only") }
  /// Block malware, ads, & trackers
  public static var quickSettingsNetshieldOptionLevel2: String { return Localizable.tr("Localizable", "_quick_settings_netshield_option_level2", fallback: "Block malware, ads, & trackers") }
  /// Don't block
  public static var quickSettingsNetshieldOptionOff: String { return Localizable.tr("Localizable", "_quick_settings_netshield_option_off", fallback: "Don't block") }
  /// Route your most sensitive data through our safest servers in privacy-friendly countries.
  public static var quickSettingsSecureCoreDescription: String { return Localizable.tr("Localizable", "_quick_settings_secureCore_description", fallback: "Route your most sensitive data through our safest servers in privacy-friendly countries.") }
  /// Secure Core may reduce VPN speed
  public static var quickSettingsSecureCoreNote: String { return Localizable.tr("Localizable", "_quick_settings_secureCore_note", fallback: "Secure Core may reduce VPN speed") }
  /// Quick Settings
  public static var quickSettingsTitle: String { return Localizable.tr("Localizable", "_quick_settings_title", fallback: "Quick Settings") }
  /// MacOS: quit application button in custom status menu
  public static var quit: String { return Localizable.tr("Localizable", "_quit", fallback: "Quit") }
  /// MacOS: alert show before quitting app if VPN is connected
  public static var quitWarning: String { return Localizable.tr("Localizable", "_quit_warning", fallback: "Quitting the application will disconnect the active VPN connection. Do you want to continue?") }
  /// Profile create/change form and other places describing profile
  public static var random: String { return Localizable.tr("Localizable", "_random", fallback: "Random") }
  /// Profile create/change form
  public static var randomAvailableServer: String { return Localizable.tr("Localizable", "_random_available_server", fallback: "Random available server") }
  /// iOS: Predefined profile with random server
  public static var randomConnection: String { return Localizable.tr("Localizable", "_random_connection", fallback: "Random") }
  /// iOS: table header section in profiles screen
  public static var recommended: String { return Localizable.tr("Localizable", "_recommended", fallback: "Recommended") }
  /// MacOS: Body of alert shown when user changed some settings and connection has to be re-established
  public static var reconnectOnSettingsChangeBody: String { return Localizable.tr("Localizable", "_reconnect_on_settings_change_body", fallback: "Your connection needs to be restarted to apply this change.") }
  /// We are reconnecting to the fastest server available.
  public static var reconnectTitle: String { return Localizable.tr("Localizable", "_reconnect_title", fallback: "We are reconnecting to the fastest server available.") }
  /// Reconnecting to %@
  public static func reconnectingTo(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_reconnecting_to", String(describing: p1), fallback: "Reconnecting to %@")
  }
  /// iOS & MacOS: text that requires restart connection
  public static var reconnectionRequired: String { return Localizable.tr("Localizable", "_reconnection_required", fallback: "Reconnection Required") }
  /// Re-establishing VPN connection.
  public static var reestablishVpnConnection: String { return Localizable.tr("Localizable", "_reestablish_vpn_connection_", fallback: "Re-establishing VPN connection.") }
  /// MacOS: About window
  public static var releaseDate: String { return Localizable.tr("Localizable", "_release_date", fallback: "Release date:") }
  /// MacOS: label in login and settings screens
  public static var rememberLogin: String { return Localizable.tr("Localizable", "_remember_login", fallback: "Remember sign in") }
  /// Button in Kill switch error alert
  public static var report: String { return Localizable.tr("Localizable", "_report", fallback: "Report") }
  /// Main mac app menu item
  public static var reportAnIssue: String { return Localizable.tr("Localizable", "_report_an_issue", fallback: "Report an Issue...") }
  /// Bug report attachments
  public static var reportAttachments: String { return Localizable.tr("Localizable", "_report_attachments", fallback: "Attachments") }
  /// Mag bug report: attach logs checkbox
  public static var reportAttachmentsCheckbox: String { return Localizable.tr("Localizable", "_report_attachments_checkbox", fallback: "Include app logs and system details") }
  /// Report bug screen title; iOS settings screen: item;
  public static var reportBug: String { return Localizable.tr("Localizable", "_report_bug", fallback: "Report an issue") }
  /// Mac bug report: description text before bug report form
  public static var reportDescription: String { return Localizable.tr("Localizable", "_report_description", fallback: "Providing the following details, our team can identify your problem and a possible solution with higher chances and shorter time:\n• Proton VPN app logs\n• OpenVPN logs\n• WireGuard logs") }
  /// Mac bug report: email field label
  public static var reportFieldEmail: String { return Localizable.tr("Localizable", "_report_field_email", fallback: "Email:") }
  /// Mac bug report: feedback field label
  public static var reportFieldFeedback: String { return Localizable.tr("Localizable", "_report_field_feedback", fallback: "What went wrong?") }
  /// Mag bug report: textfields placeholder
  public static var reportFieldPlaceholder: String { return Localizable.tr("Localizable", "_report_field_placeholder", fallback: "Start typing...") }
  /// Mac bug report: steps field label
  public static var reportFieldSteps: String { return Localizable.tr("Localizable", "_report_field_steps", fallback: "What are the exact steps you performed?") }
  /// iOS bug report: header before logs description
  public static var reportLogs: String { return Localizable.tr("Localizable", "_report_logs", fallback: "VPN logs") }
  /// iOS bug report: description of log selection switch
  public static var reportLogsDescription: String { return Localizable.tr("Localizable", "_report_logs_description", fallback: "Enabling this will add your client side VPN logs to this report") }
  /// iOS bug report: Placeholder for email form field
  public static var reportPlaceholderEmail: String { return Localizable.tr("Localizable", "_report_placeholder_email", fallback: "Contact email") }
  /// Bug report: Placeholder for text form field
  public static var reportPlaceholderMessage: String { return Localizable.tr("Localizable", "_report_placeholder_message", fallback: "Your message...") }
  /// iOS bug report: Title before report bug form
  public static var reportReport: String { return Localizable.tr("Localizable", "_report_report", fallback: "Report message") }
  /// Bug report: Send report button text
  public static var reportSend: String { return Localizable.tr("Localizable", "_report_send", fallback: "Send Report") }
  /// Bug report: Success message after report was sent
  public static var reportSuccess: String { return Localizable.tr("Localizable", "_report_success", fallback: "Thank you for your report") }
  /// iOS: human verification option select button
  public static var requestInvitation: String { return Localizable.tr("Localizable", "_request_invitation", fallback: "Request manual activation") }
  /// iOS: button in human verification code form
  public static var resendCode: String { return Localizable.tr("Localizable", "_resend_code", fallback: "Request new code") }
  /// iOS: button in human verification code form
  public static var resendNoCode: String { return Localizable.tr("Localizable", "_resend_no_code", fallback: "Didn't get the code?") }
  /// iOS: message after human verification code resending
  public static var resendSuccess: String { return Localizable.tr("Localizable", "_resend_success", fallback: "New code requested") }
  /// MacOS: button in login screen
  public static var resetPassword: String { return Localizable.tr("Localizable", "_reset_password", fallback: "Reset Password") }
  /// Button in some alerts
  public static var retry: String { return Localizable.tr("Localizable", "_retry", fallback: "Retry") }
  /// Common word
  public static var save: String { return Localizable.tr("Localizable", "_save", fallback: "Save") }
  /// Button
  public static var saveAsProfile: String { return Localizable.tr("Localizable", "_save_as_profile", fallback: "Save as Profile") }
  /// MacOS: placeholder for country search
  public static var searchForCountry: String { return Localizable.tr("Localizable", "_search_for_country", fallback: "Search for country") }
  /// iOS: placeholder in phone country code selection screen
  public static var searchPhoneCountryCodePlaceholder: String { return Localizable.tr("Localizable", "_search_phone_country_code_placeholder", fallback: "Search country") }
  /// Used in many places in MacOS app
  public static var secureCore: String { return Localizable.tr("Localizable", "_secure_core", fallback: "Secure Core") }
  /// %@ is a country e.g. Secure Core Switzerland
  public static func secureCoreCountry(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_secure_core_country", String(describing: p1), fallback: "Secure Core %@")
  }
  /// MacOS: \Trial about to expire\ screen
  public static var secureCoreDescription: String { return Localizable.tr("Localizable", "_secure_core_description", fallback: "Ultra secure servers\nhosted by us") }
  /// MacOS: secure core tooltip
  public static var secureCoreInfo: String { return Localizable.tr("Localizable", "_secure_core_info", fallback: "Provides additional protection against VPN server compromise by routing traffic through our Secure Core Network") }
  /// Secure core: connected to a country via another country. %@ is the country through which we are transiting to get to the final destination. [Redesign_2023]
  public static func secureCoreViaCountry(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_secure_core_via_country", String(describing: p1), fallback: "via %@")
  }
  /// MacOS: \Trial about to expire\ screen
  public static var secureStreamingDescription: String { return Localizable.tr("Localizable", "_secure_streaming_description", fallback: "Secure streaming of your\nfavorite content") }
  /// MacOS: \Trial about to expire\ screen
  public static var secureStreamingTitle: String { return Localizable.tr("Localizable", "_secure_streaming_title", fallback: "Secure Streaming") }
  /// iOS status view
  public static var security: String { return Localizable.tr("Localizable", "_security", fallback: "Security") }
  /// iOS Settings: table section header
  public static var securityOptions: String { return Localizable.tr("Localizable", "_security_options", fallback: "Security Options") }
  /// Profile create/change form
  public static var selectCountry: String { return Localizable.tr("Localizable", "_select_country", fallback: "Select Country") }
  /// iOS: title of phone country code selection screen
  public static var selectPhoneCountryCode: String { return Localizable.tr("Localizable", "_select_phone_country_code", fallback: "Select Country Code") }
  /// Button in plan selection
  public static var selectPlan: String { return Localizable.tr("Localizable", "_select_plan", fallback: "Select plan") }
  /// iOS: new profile screen
  public static var selectProfileColor: String { return Localizable.tr("Localizable", "_select_profile_color", fallback: "Select profile color") }
  /// Profile create/change form
  public static var selectServer: String { return Localizable.tr("Localizable", "_select_server", fallback: "Select Server") }
  /// iOS: text in human verification options screen
  public static var selectVerificationOption: String { return Localizable.tr("Localizable", "_select_verification_option", fallback: "Please select a verification option to proceed:") }
  /// iOS: text in human verification options screen
  public static var selectVerificationOptionTopMessage: String { return Localizable.tr("Localizable", "_select_verification_option_top_message", fallback: "To prevent abuse, you must verify you are a human.") }
  /// Profile create/change form
  public static var server: String { return Localizable.tr("Localizable", "_server", fallback: "Server") }
  /// MacOS: label in server info view (shown after click on Info icon in countries list
  public static var serverIp: String { return Localizable.tr("Localizable", "_server_ip", fallback: "Server IP:") }
  /// MacOS: label in server info view (shown after click on Info icon in countries list
  public static var serverLoad: String { return Localizable.tr("Localizable", "_server_load", fallback: "Server Load:") }
  /// Server load percentage, shown in the sidebar header when connected to a server. Also shown in the tooltip when hovering over a server load icon in the sidebar country list. %@ is a placeholder for the numeric percentage value.
  public static func serverLoadPercentage(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_server_load_percentage", String(describing: p1), fallback: "%@%% Load")
  }
  /// Server Load
  public static var serverLoadTitle: String { return Localizable.tr("Localizable", "_server_load_title", fallback: "Server Load") }
  /// Error when user hasn't selected profile server
  public static var serverSelectionIsRequired: String { return Localizable.tr("Localizable", "_server_selection_is_required", fallback: "Please select a server") }
  /// Under maintenance alert
  public static var serverUnderMaintenance: String { return Localizable.tr("Localizable", "_server_under_maintenance", fallback: "Server under maintenance") }
  /// Plural format key: "%#@DAYS@"
  public static func sessionLengthDays(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "_session_length_days", p1, fallback: "Plural format key: \"%#@DAYS@\"")
  }
  /// Plural format key: "%#@DAYS@ %#@HOURS@"
  public static func sessionLengthDaysAndHours(_ p1: Int, _ p2: Int) -> String {
    return Localizable.tr("Localizable", "_session_length_days_and_hours", p1, p2, fallback: "Plural format key: \"%#@DAYS@ %#@HOURS@\"")
  }
  /// Plural format key: "%#@HOURS@"
  public static func sessionLengthHours(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "_session_length_hours", p1, fallback: "Plural format key: \"%#@HOURS@\"")
  }
  /// Plural format key: "%#@HOURS@ %#@MINUTES@"
  public static func sessionLengthHoursAndMinutes(_ p1: Int, _ p2: Int) -> String {
    return Localizable.tr("Localizable", "_session_length_hours_and_minutes", p1, p2, fallback: "Plural format key: \"%#@HOURS@ %#@MINUTES@\"")
  }
  /// Plural format key: "%#@MINUTES@"
  public static func sessionLengthMinutes(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "_session_length_minutes", p1, fallback: "Plural format key: \"%#@MINUTES@\"")
  }
  /// Plural format key: "%#@MINUTES@ %#@SECONDS@"
  public static func sessionLengthMinutesAndSeconds(_ p1: Int, _ p2: Int) -> String {
    return Localizable.tr("Localizable", "_session_length_minutes_and_seconds", p1, p2, fallback: "Plural format key: \"%#@MINUTES@ %#@SECONDS@\"")
  }
  /// Plural format key: "%#@SECONDS@"
  public static func sessionLengthSeconds(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "_session_length_seconds", p1, fallback: "Plural format key: \"%#@SECONDS@\"")
  }
  /// iOS status view
  public static var sessionTime: String { return Localizable.tr("Localizable", "_session_time", fallback: "Session Time") }
  /// iOS: Settings screen title and tab title
  public static var settings: String { return Localizable.tr("Localizable", "_settings", fallback: "Settings") }
  /// Text describing the app version in the footer of the Settings tab. %@ will be replaced by a version number in the form of 5.0.0 (1234567890) [Redesign_2023]
  public static func settingsAppVersion(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_settings_app_version", String(describing: p1), fallback: "App Version: %@")
  }
  /// Represents the OFF state of the Kill Switch feature. Displayed in the Kill Switch settings cell in the Settings tab, and when drilled into the Kill Switch settings view [Redesign_2023]
  public static var settingsKillswitchOff: String { return Localizable.tr("Localizable", "_settings_killswitch_off", fallback: "Off") }
  /// Represents the ON state of the Kill Switch feature. Displayed in the Kill Switch settings cell in the Settings tab, and when drilled into the Kill Switch settings view [Redesign_2023]
  public static var settingsKillswitchOn: String { return Localizable.tr("Localizable", "_settings_killswitch_on", fallback: "On") }
  /// Telemetry label in the settings window for mac
  public static var settingsMacCrashReportsTitle: String { return Localizable.tr("Localizable", "_settings_mac_crash_reports_title", fallback: "Share anonymous crash reports") }
  /// Telemetry tooltip in the settings window for mac
  public static var settingsMacCrashReportsTooltip: String { return Localizable.tr("Localizable", "_settings_mac_crash_reports_tooltip", fallback: "Crash reports help us fix bugs, detect firewalls, and avoid VPN blocks.") }
  /// Clickable label title in the onboarding screen for mac
  public static var settingsMacTelemetryLearnMore: String { return Localizable.tr("Localizable", "_settings_mac_telemetry_learn_more", fallback: "Learn more") }
  /// Telemetry label in the settings window for mac
  public static var settingsMacUsageStatsTitle: String { return Localizable.tr("Localizable", "_settings_mac_usage_stats_title", fallback: "Share anonymous usage statistics") }
  /// Telemetry tooltip in the settings window for mac
  public static var settingsMacUsageStatsTooltip: String { return Localizable.tr("Localizable", "_settings_mac_usage_stats_tooltip", fallback: "Usage data helps us overcome VPN blocks and improve app performance.") }
  /// Represents the OFF state of the NetShield feature. Displayed in the NetShield settings cell in the Settings tab, and when drilled into the NetShield settings view [Redesign_2023]
  public static var settingsNetshieldOff: String { return Localizable.tr("Localizable", "_settings_netshield_off", fallback: "Off") }
  /// Represents the ON state of the NetShield feature. Displayed in the NetShield settings cell in the Settings tab, and when drilled into the NetShield settings view [Redesign_2023]
  public static var settingsNetshieldOn: String { return Localizable.tr("Localizable", "_settings_netshield_on", fallback: "On") }
  /// Body of an alert shown in Protocol Settings, when the user attempts to select a different protocol, while a VPN Connection is active. The alert warns the user that changing the VPN protocol will require the current VPN session to be disconnected. [Redesign_2023]
  public static var settingsProtocolAlertBody: String { return Localizable.tr("Localizable", "_settings_protocol_alert_body", fallback: "Changing protocols will end your current VPN session.") }
  /// Cancel button text for the protocol change reconnection alert in Protocol Settings. The alert warns the user that changing the VPN protocol will require the current VPN session to be disconnected. [Redesign_2023]
  public static var settingsProtocolAlertButtonCancel: String { return Localizable.tr("Localizable", "_settings_protocol_alert_button_cancel", fallback: "Cancel") }
  /// Confirmation button text for the protocol change reconnection alert in Protocol Settings. The alert warns the user that changing the VPN protocol will require the current VPN session to be disconnected. [Redesign_2023]
  public static var settingsProtocolAlertButtonContinue: String { return Localizable.tr("Localizable", "_settings_protocol_alert_button_continue", fallback: "Continue") }
  /// Title of an alert shown in Protocol Settings, when the user attempts to select a different protocol, while a VPN Connection is active. The alert warns the user that changing the VPN protocol will require the current VPN session to be disconnected. [Redesign_2023]
  public static var settingsProtocolAlertTitle: String { return Localizable.tr("Localizable", "_settings_protocol_alert_title", fallback: "VPN Connection Active") }
  /// Description of the IKEv2 protocol in the protocol settings screen [Redesign_2023]
  public static var settingsProtocolDescriptionIkev2: String { return Localizable.tr("Localizable", "_settings_protocol_description_ikev2", fallback: "Fast, secure, and stable—but easier for censors to detect and block.") }
  /// Description of the OpenVPN (TCP) protocol in the protocol settings screen [Redesign_2023]
  public static var settingsProtocolDescriptionOpenvpnTcp: String { return Localizable.tr("Localizable", "_settings_protocol_description_openvpn_tcp", fallback: "Established, well-tested, and secure. OpenVPN is reliable in poor network conditions, but may not be as fast as other protocols.") }
  /// Description of the OpenVPN (UDP) protocol in the protocol settings screen [Redesign_2023]
  public static var settingsProtocolDescriptionOpenvpnUdp: String { return Localizable.tr("Localizable", "_settings_protocol_description_openvpn_udp", fallback: "Established, well-tested, and secure. OpenVPN is less battery-efficient than some other protocols.") }
  /// Description of the smart protocol in the protocol settings screen [Redesign_2023]
  public static var settingsProtocolDescriptionSmart: String { return Localizable.tr("Localizable", "_settings_protocol_description_smart", fallback: "Auto-selects the best protocol for your connection.") }
  /// Description of the WireGuard (TCP) protocol in the protocol settings screen [Redesign_2023]
  public static var settingsProtocolDescriptionWireguardTcp: String { return Localizable.tr("Localizable", "_settings_protocol_description_wireguard_tcp", fallback: "Fast, secure, and efficient. WireGuard is difficult to detect and block.") }
  /// Description of the Stealth (WireGuard TLS) protocol in the protocol settings screen [Redesign_2023]
  public static var settingsProtocolDescriptionWireguardTls: String { return Localizable.tr("Localizable", "_settings_protocol_description_wireguard_tls", fallback: "Overcomes VPN blocks by hiding your VPN connection from censors. This protocol is DPI (deep packet inspection) resistant, but may not be as fast as other protocols. Stealth is exclusive to Proton VPN.") }
  /// Description of the WireGuard (UDP) protocol in the protocol settings screen [Redesign_2023]
  public static var settingsProtocolDescriptionWireguardUdp: String { return Localizable.tr("Localizable", "_settings_protocol_description_wireguard_udp", fallback: "Fast, secure, and efficient. WireGuard is more battery-efficient than other protocols.") }
  /// Footer at the bottom of the Protocol Settings screen. Formatted with markdown, to embed a hyperlink to https://protonvpn.com/blog/whats-the-best-vpn-protocol/ [Redesign_2023]
  public static var settingsProtocolFooter: String { return Localizable.tr("Localizable", "_settings_protocol_footer", fallback: "A VPN protocol determines how data moves between a VPN server and your device. **[Learn more](https://protonvpn.com/blog/whats-the-best-vpn-protocol/)**") }
  /// TCP protocols section header in the protocol settings screen [Redesign_2023]
  public static var settingsProtocolSectionTitleTcp: String { return Localizable.tr("Localizable", "_settings_protocol_section_title_tcp", fallback: "Reliability (TCP)") }
  /// UDP protocols section header in the protocol settings screen [Redesign_2023]
  public static var settingsProtocolSectionTitleUdp: String { return Localizable.tr("Localizable", "_settings_protocol_section_title_udp", fallback: "Speed (UDP)") }
  /// Text displayed next to the titles of cells of any new protocols in Protocol Settings. Displayed in uppercase, with a border around it.  [Redesign_2023]
  public static var settingsProtocolTagNew: String { return Localizable.tr("Localizable", "_settings_protocol_tag_new", fallback: "NEW") }
  /// Text displayed next to the title of the cell of the recommended protocol in Protocol Settings. Displayed in uppercase, with a border around it. [Redesign_2023]
  public static var settingsProtocolTagRecommended: String { return Localizable.tr("Localizable", "_settings_protocol_tag_recommended", fallback: "RECOMMENDED") }
  /// Title of the 'Account' section in the Settings tab [Redesign_2023]
  public static var settingsSectionTitleAccount: String { return Localizable.tr("Localizable", "_settings_section_title_account", fallback: "Account") }
  /// Title of the 'Connection' section in the Settings tab [Redesign_2023]
  public static var settingsSectionTitleConnection: String { return Localizable.tr("Localizable", "_settings_section_title_connection", fallback: "Connection") }
  /// Title of the 'Features' section in the Settings tab [Redesign_2023]
  public static var settingsSectionTitleFeatures: String { return Localizable.tr("Localizable", "_settings_section_title_features", fallback: "Features") }
  /// Title of the 'General' section in the Settings tab [Redesign_2023]
  public static var settingsSectionTitleGeneral: String { return Localizable.tr("Localizable", "_settings_section_title_general", fallback: "General") }
  /// Title of the 'Improve Proton' section in the Settings tab [Redesign_2023]
  public static var settingsSectionTitleImproveProton: String { return Localizable.tr("Localizable", "_settings_section_title_improve_proton", fallback: "Improve Proton") }
  /// Title of the 'Support' section in the Settings tab [Redesign_2023]
  public static var settingsSectionTitleSupport: String { return Localizable.tr("Localizable", "_settings_section_title_support", fallback: "Support") }
  /// Settings tab in bottom menu [Redesign_2023]
  public static var settingsTab: String { return Localizable.tr("Localizable", "_settings_tab", fallback: "Settings") }
  /// Represents a value of Auto for the app theme setting. Displayed underneath the corresponding option when drilled into the Theme settings view. An asterisk is appended to this string to point to a disclaimer below, clarifying that the app theme will be based on the system theme [Redesign_2023]
  public static var settingsThemeLabelAuto: String { return Localizable.tr("Localizable", "_settings_theme_label_auto", fallback: "Auto*") }
  /// Represents a value of dark mode for the app theme setting. Displayed underneath the corresponding option when drilled into the Theme settings view [Redesign_2023]
  public static var settingsThemeLabelDark: String { return Localizable.tr("Localizable", "_settings_theme_label_dark", fallback: "Dark") }
  /// Represents a value of light mode for the app theme setting. Displayed underneath the corresponding option when drilled into the Theme settings view [Redesign_2023]
  public static var settingsThemeLabelLight: String { return Localizable.tr("Localizable", "_settings_theme_label_light", fallback: "Light") }
  /// Represents a value of Auto for the app theme setting. Displayed in the Theme settings cell in the Settings tab [Redesign_2023]
  public static var settingsThemeValueAuto: String { return Localizable.tr("Localizable", "_settings_theme_value_auto", fallback: "Auto") }
  /// Represents a value of dark mode for the app theme setting. Displayed in the Theme settings cell in the Settings tab [Redesign_2023]
  public static var settingsThemeValueDark: String { return Localizable.tr("Localizable", "_settings_theme_value_dark", fallback: "Dark") }
  /// Represents a value of light mode for the app theme setting. Displayed in the Theme settings cell in the Settings tab [Redesign_2023]
  public static var settingsThemeValueLight: String { return Localizable.tr("Localizable", "_settings_theme_value_light", fallback: "Light") }
  /// Title at the top of the Settings tab [Redesign_2023]
  public static var settingsTitle: String { return Localizable.tr("Localizable", "_settings_title", fallback: "Settings") }
  /// Title of the Advanced Settings cell in the Settings tab [Redesign_2023]
  public static var settingsTitleAdvanced: String { return Localizable.tr("Localizable", "_settings_title_advanced", fallback: "Advanced settings") }
  /// Title of the Beta Access cell in the Settings tab [Redesign_2023]
  public static var settingsTitleBetaAccess: String { return Localizable.tr("Localizable", "_settings_title_beta_access", fallback: "Beta access") }
  /// Title of the Help us fight censorship cell in the Settings tab [Redesign_2023]
  public static var settingsTitleCensorship: String { return Localizable.tr("Localizable", "_settings_title_censorship", fallback: "Help us fight censorship") }
  /// Title of the Debug Logs cell in the Settings tab [Redesign_2023]
  public static var settingsTitleDebugLogs: String { return Localizable.tr("Localizable", "_settings_title_debug_logs", fallback: "Debug logs") }
  /// Title of the KillSwitch cell in the Settings tab [Redesign_2023]
  public static var settingsTitleKillSwitch: String { return Localizable.tr("Localizable", "_settings_title_kill_switch", fallback: "Kill Switch") }
  /// Title of the NetShield cell in the Settings tab [Redesign_2023]
  public static var settingsTitleNetshield: String { return Localizable.tr("Localizable", "_settings_title_netshield", fallback: "NetShield") }
  /// Title of the Protocol cell in the Settings tab [Redesign_2023]
  public static var settingsTitleProtocol: String { return Localizable.tr("Localizable", "_settings_title_protocol", fallback: "Protocol") }
  /// Title of the Rate Proton VPN cell in the Settings tab [Redesign_2023]
  public static var settingsTitleRate: String { return Localizable.tr("Localizable", "_settings_title_rate", fallback: "Rate Proton VPN") }
  /// Title of the Report an Issue cell in the Settings tab [Redesign_2023]
  public static var settingsTitleReportIssue: String { return Localizable.tr("Localizable", "_settings_title_report_issue", fallback: "Report an issue") }
  /// Title of the Restore default settings cell in the Settings tab [Redesign_2023]
  public static var settingsTitleRestoreDefaultSettings: String { return Localizable.tr("Localizable", "_settings_title_restore_default_settings", fallback: "Restore default settings") }
  /// Title of the Sign Out cell in the Settings tab [Redesign_2023]
  public static var settingsTitleSignOut: String { return Localizable.tr("Localizable", "_settings_title_sign_out", fallback: "Sign out") }
  /// Title of the Support Center cell in the Settings tab [Redesign_2023]
  public static var settingsTitleSupportCenter: String { return Localizable.tr("Localizable", "_settings_title_support_center", fallback: "Support center") }
  /// Title of the Theme cell in the Settings tab [Redesign_2023]
  public static var settingsTitleTheme: String { return Localizable.tr("Localizable", "_settings_title_theme", fallback: "Theme") }
  /// Title of the VPN Accelerator cell in the Settings tab [Redesign_2023]
  public static var settingsTitleVpnAccelerator: String { return Localizable.tr("Localizable", "_settings_title_vpn_accelerator", fallback: "VPN Accelerator") }
  /// Title of the Widget cell in the Settings tab [Redesign_2023]
  public static var settingsTitleWidget: String { return Localizable.tr("Localizable", "_settings_title_widget", fallback: "Widget") }
  /// iOS: title of the screen after successfull purchase
  public static var setupComplete: String { return Localizable.tr("Localizable", "_setup_complete", fallback: "Setup Complete") }
  /// iOS: title of the screen after successfull purchase
  public static var setupCompleteFree: String { return Localizable.tr("Localizable", "_setup_complete_free", fallback: "You are now signed up for a Proton VPN Free plan. To get you started, enjoy seven days of our Proton VPN Plus plan for free.") }
  /// iOS: title of the screen after successfull purchase
  public static var setupCompletePlus: String { return Localizable.tr("Localizable", "_setup_complete_plus", fallback: "Your purchase was successful. Your Proton VPN Plus plan is now active.") }
  /// Show/hide password switch
  public static var show: String { return Localizable.tr("Localizable", "_show", fallback: "SHOW") }
  /// Home screen: Connection card hint on hover (macOS) [Redesign_2023]
  public static var showConnectionDetailsButtonHint: String { return Localizable.tr("Localizable", "_show_connection_details_button_hint", fallback: "Show connection details") }
  /// Button in some alerts
  public static var showInstructions: String { return Localizable.tr("Localizable", "_show_instructions", fallback: "Show instructions") }
  /// Show Proton VPN
  public static var showProtonvpn: String { return Localizable.tr("Localizable", "_show_protonvpn", fallback: "Show Proton VPN") }
  /// iOS: button in login and onboarding screens
  public static var signUp: String { return Localizable.tr("Localizable", "_sign_up", fallback: "Sign Up") }
  /// Description for Smart Protocol in Settings
  public static var smartProtocolDescription: String { return Localizable.tr("Localizable", "_smart_protocol_description", fallback: "Enable Smart Protocol to automatically use the protocol and port that offers the best connectivity.") }
  /// Body for the modal dialog shown when trying to change Smart Protocol in Settings while connected
  public static var smartProtocolReconnectModalBody: String { return Localizable.tr("Localizable", "_smart_protocol_reconnect_modal_body", fallback: "Your connection will be restarted to change the Smart Protocol mode.") }
  /// Title for the modal dialog shown when trying to change Smart Protocol in Settings while connected
  public static var smartProtocolReconnectModalTitle: String { return Localizable.tr("Localizable", "_smart_protocol_reconnect_modal_title", fallback: "Reconnection required") }
  /// Title for Smart Protocol in Settings
  public static var smartProtocolTitle: String { return Localizable.tr("Localizable", "_smart_protocol_title", fallback: "Smart Protocol") }
  /// Smart Routing
  public static var smartRoutingTitle: String { return Localizable.tr("Localizable", "_smart_routing_title", fallback: "Smart Routing") }
  /// Shortened title for Smart Protocol on Settings configuration
  public static var smartTitle: String { return Localizable.tr("Localizable", "_smart_title", fallback: "Smart") }
  /// %@ is a speed description e.g. Speed: Highest
  public static func speed(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_speed", String(describing: p1), fallback: "%@ speed")
  }
  /// MacOS: generic failure message for SSO login
  public static var ssoLoginFailure: String { return Localizable.tr("Localizable", "_sso_login_failure", fallback: "Failed to log in with SSO. Please try again.") }
  /// MacOS profile form: feature selection value
  public static var standard: String { return Localizable.tr("Localizable", "_standard", fallback: "Standard") }
  /// MacOS: Settings -> General: name of field.
  public static var startMinimized: String { return Localizable.tr("Localizable", "_start_minimized", fallback: "Start Minimized") }
  /// MacOS: label in login and settings screens
  public static var startOnBoot: String { return Localizable.tr("Localizable", "_start_on_boot", fallback: "Start on Boot") }
  /// iOS status view
  public static var status: String { return Localizable.tr("Localizable", "_status", fallback: "Status") }
  /// Plural format key: "%#@STEP@ %#@STEPS@"
  public static func stepOf(_ p1: Int, _ p2: Int) -> String {
    return Localizable.tr("Localizable", "_step_of", p1, p2, fallback: "Plural format key: \"%#@STEP@ %#@STEPS@\"")
  }
  /// Connect to a Plus server in this country to start streaming.
  public static var streamingServersDescription: String { return Localizable.tr("Localizable", "_streaming_servers_description", fallback: "Connect to a Plus server in this country to start streaming.") }
  /// and more
  public static var streamingServersExtra: String { return Localizable.tr("Localizable", "_streaming_servers_extra", fallback: "and more") }
  /// Note: Turn off the Location Service and clear the cache of the streaming apps to ensure new content appears.
  public static var streamingServersNote: String { return Localizable.tr("Localizable", "_streaming_servers_note", fallback: "Note: Turn off the Location Service and clear the cache of the streaming apps to ensure new content appears.") }
  /// Streaming
  public static var streamingTitle: String { return Localizable.tr("Localizable", "_streaming_title", fallback: "Streaming") }
  /// iOS: button in human verification code form
  public static var submitVerificationCode: String { return Localizable.tr("Localizable", "_submit_verification_code", fallback: "Submit") }
  /// Extend plan for 1 year 
  /// %@.
  public static func subscriptionButton(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_subscription_button", String(describing: p1), fallback: "Extend plan for 1 year \n%@.")
  }
  /// You can purchase more credits to automatically extend your current plan. At the end of your current subscription period, these credits will be applied to continue your plan.
  public static var subscriptionDescription: String { return Localizable.tr("Localizable", "_subscription_description", fallback: "You can purchase more credits to automatically extend your current plan. At the end of your current subscription period, these credits will be applied to continue your plan.") }
  /// Your subscription has been downgraded.
  public static var subscriptionExpiredDescription: String { return Localizable.tr("Localizable", "_subscription_expired_description", fallback: "Your subscription has been downgraded.") }
  /// Your subscription has been downgraded, so we are reconnecting to the fastest available server.
  public static var subscriptionExpiredReconnectionDescription: String { return Localizable.tr("Localizable", "_subscription_expired_reconnection_description", fallback: "Your subscription has been downgraded, so we are reconnecting to the fastest available server.") }
  /// Your VPN subscription plan has expired
  public static var subscriptionExpiredTitle: String { return Localizable.tr("Localizable", "_subscription_expired_title", fallback: "Your VPN subscription plan has expired") }
  /// You have successfully bought credits to extend your current plan.
  public static var subscriptionExtendedSuccess: String { return Localizable.tr("Localizable", "_subscription_extended_success", fallback: "You have successfully bought credits to extend your current plan.") }
  /// iOS Settings -> Connection: name of field.
  public static var subscriptionPlan: String { return Localizable.tr("Localizable", "_subscription_plan", fallback: "Subscription Plan") }
  /// Advanced features: NetShield, Secure Core, Tor, P2P
  public static var subscriptionUpgradeOption3: String { return Localizable.tr("Localizable", "_subscription_upgrade_option3", fallback: "Advanced features: NetShield, Secure Core, Tor, P2P") }
  /// Upgrade again to enjoy all the features:
  public static var subscriptionUpgradeTitle: String { return Localizable.tr("Localizable", "_subscription_upgrade_title", fallback: "Upgrade again to enjoy all the features:") }
  /// Current plan will expire on %@.
  public static func subscriptionWillExpire(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_subscription_will_expire", String(describing: p1), fallback: "Current plan will expire on %@.")
  }
  /// Current plan will automatically renew on %@.
  public static func subscriptionWillRenew(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_subscription_will_renew", String(describing: p1), fallback: "Current plan will automatically renew on %@.")
  }
  /// To start your journey in Proton VPN please enable VPN connections to your account or any other sub-account.
  public static var subuserAlertDescription1: String { return Localizable.tr("Localizable", "_subuser_alert_description1", fallback: "To start your journey in Proton VPN please enable VPN connections to your account or any other sub-account.") }
  /// This step will take just a few minutes. After that you will be able to sign in and protect all your devices.
  public static var subuserAlertDescription2: String { return Localizable.tr("Localizable", "_subuser_alert_description2", fallback: "This step will take just a few minutes. After that you will be able to sign in and protect all your devices.") }
  /// There is currently no VPN connection enabled for this account. To start your journey with Proton VPN please contact your administrator.
  public static var subuserAlertDescription3: String { return Localizable.tr("Localizable", "_subuser_alert_description3", fallback: "There is currently no VPN connection enabled for this account. To start your journey with Proton VPN please contact your administrator.") }
  /// Enable VPN connections
  public static var subuserAlertEnableConnectionsButton: String { return Localizable.tr("Localizable", "_subuser_alert_enable_connections_button", fallback: "Enable VPN connections") }
  /// Sign in again
  public static var subuserAlertLoginButton: String { return Localizable.tr("Localizable", "_subuser_alert_login_button", fallback: "Sign in again") }
  /// Thanks for upgrading to Business/Visionary
  public static var subuserAlertTitle: String { return Localizable.tr("Localizable", "_subuser_alert_title", fallback: "Thanks for upgrading to Business/Visionary") }
  /// MacOS: connecting overlay
  public static var successfullyConnected: String { return Localizable.tr("Localizable", "_successfully_connected", fallback: "Successfully Connected") }
  /// OFF
  public static var switchSideButtonOff: String { return Localizable.tr("Localizable", "_switch_side_button_off", fallback: "OFF") }
  /// ON
  public static var switchSideButtonOn: String { return Localizable.tr("Localizable", "_switch_side_button_on", fallback: "ON") }
  /// Cannot enable System Extension
  public static var sysexCannotEnable: String { return Localizable.tr("Localizable", "_sysex_cannot_enable", fallback: "Cannot enable System Extension") }
  /// Part 1 of the description of the system extension wizard in mac. The whole text: "To use Proton VPN, you’ll need to enable custom VPN protocols on your Mac. Custom protocols allow for faster and more secure connections, and you’ll need them enabled to connect to most Proton VPN servers. To continue, click Open Security Preferences, then follow the video instructions on this screen."
  public static var sysexDescription1: String { return Localizable.tr("Localizable", "_sysex_description_1", fallback: "To use Proton VPN, you’ll need to enable **custom VPN protocols** on your Mac.") }
  /// Part 2 of the description of the system extension wizard in mac
  public static var sysexDescription2: String { return Localizable.tr("Localizable", "_sysex_description_2", fallback: "Custom protocols allow for faster and more secure connections, and you’ll need them enabled to connect to most Proton VPN servers.") }
  /// Part 3 of the description of the system extension wizard in mac. Text in bold is the same as the title of the button in the system alert when installing system extensions
  public static var sysexDescription3: String { return Localizable.tr("Localizable", "_sysex_description_3", fallback: "To continue, click **Open System Settings**, then follow the video instructions on this screen.") }
  /// Alternative for Part 3 for pre-ventura of the description of the system extension wizard in mac. Text in bold is the same as the title of the button in the system alert when installing system extensions
  public static var sysexDescription4: String { return Localizable.tr("Localizable", "_sysex_description_4", fallback: "To continue, click **Open Security Preferences**, then follow the video instructions on this screen.") }
  /// Configuration completed. Now you can browse the internet faster with the best VPN technologies.
  public static var sysexEnabledDescription: String { return Localizable.tr("Localizable", "_sysex_enabled_description", fallback: "Configuration completed. Now you can browse the internet faster with the best VPN technologies.") }
  /// Configuration completed
  public static var sysexEnabledTitle: String { return Localizable.tr("Localizable", "_sysex_enabled_title", fallback: "Configuration completed") }
  /// An error occurred while installing System Extension.
  /// Reinstall Proton VPN, making sure it is located in the Applications folder, to fix this problem. Alternatively, contact our support.
  public static var sysexErrorDescription: String { return Localizable.tr("Localizable", "_sysex_error_description", fallback: "An error occurred while installing System Extension.\nReinstall Proton VPN, making sure it is located in the Applications folder, to fix this problem. Alternatively, contact our support.") }
  /// Default action in the system extension wizard in mac. macOS Ventura
  public static var sysexOpenSecurityPreferences: String { return Localizable.tr("Localizable", "_sysex_open_security_preferences", fallback: "Open Security Preferences") }
  /// Default action in the system extension wizard in mac. Pre-macOS Ventura
  public static var sysexOpenSystemSettings: String { return Localizable.tr("Localizable", "_sysex_open_system_settings", fallback: "Open System Settings") }
  /// Title of the system extension wizard in mac
  public static var sysexSetUpProtonVpn: String { return Localizable.tr("Localizable", "_sysex_set_up_proton_vpn", fallback: "Set up Proton VPN") }
  /// Proton VPN requires to load a System Extension to leverage Smart Protocol, OpenVPN and WireGuard.
  public static var sysexSettingsDescription: String { return Localizable.tr("Localizable", "_sysex_settings_description", fallback: "Proton VPN requires to load a System Extension to leverage Smart Protocol, OpenVPN and WireGuard.") }
  /// Main mac app menu item
  public static var systemExtensionTutorialMenuItem: String { return Localizable.tr("Localizable", "_system_extension_tutorial_menu_item", fallback: "System Extension Tutorial") }
  /// MacOS: Settings -> General: name of field.
  public static var systemNotifications: String { return Localizable.tr("Localizable", "_system_notifications", fallback: "System Notifications") }
  /// iOS Settings -> Protocol -> OpenVPN/WireGuard: TCP option
  public static var tcp: String { return Localizable.tr("Localizable", "_tcp", fallback: "TCP") }
  /// iOS status view
  public static var technicalDetails: String { return Localizable.tr("Localizable", "_technical_details", fallback: "Technical Details") }
  /// iOS: link inside text under sign-up form
  public static var termsAndConditions: String { return Localizable.tr("Localizable", "_terms_and_conditions", fallback: "Terms and Conditions") }
  /// iOS: text under sign-up form. %@1 is a link with a title of 'Terms and Conditions'; %@2 is a link with a title of 'Privacy Policy'
  public static func termsAndConditionsDisclaimer(_ p1: Any, _ p2: Any) -> String {
    return Localizable.tr("Localizable", "_terms_and_conditions_disclaimer", String(describing: p1), String(describing: p2), fallback: "By using Proton VPN, you agree to our\n%@ and %@")
  }
  /// iOS: section header in countries list
  public static var testServers: String { return Localizable.tr("Localizable", "_test_servers", fallback: "TEST Servers") }
  /// Free
  public static var tierFree: String { return Localizable.tr("Localizable", "_tier_free", fallback: "Free") }
  /// Plus
  public static var tierPlus: String { return Localizable.tr("Localizable", "_tier_plus", fallback: "Plus") }
  /// Visionary
  public static var tierVisionary: String { return Localizable.tr("Localizable", "_tier_visionary", fallback: "Visionary") }
  /// MacOS: shown when connection timed out and user has problematic setup involving ikev2 and kill switch on
  public static var timeoutKsIkeDescritpion: String { return Localizable.tr("Localizable", "_timeout_ks_ike_descritpion", fallback: "Another application might be interfering with kill switch. To fix this problem, switch to the OpenVPN protocol or disable kill switch and retry.") }
  /// MacOS: button shown when connection timed out and user has problematic setup involving ikev2 and kill switch on. Don't make this text longer than in english.
  public static var timeoutKsIkeSwitchProtocol: String { return Localizable.tr("Localizable", "_timeout_ks_ike_switch_protocol", fallback: "Switch to OpenVPN and retry") }
  /// iOS Settings -> Protocol -> WireGuard: TLS option
  public static var tls: String { return Localizable.tr("Localizable", "_tls", fallback: "TLS") }
  /// To Server:
  public static var toServerTitle: String { return Localizable.tr("Localizable", "_to_server_title", fallback: "To Server:") }
  /// MacOS profile form: feature selection value; iOS: country.server description in countries list;
  public static var tor: String { return Localizable.tr("Localizable", "_tor", fallback: "TOR") }
  /// Description shown together with server info icon
  public static var torDescription: String { return Localizable.tr("Localizable", "_tor_description", fallback: "Connects to TOR network") }
  /// MacOS: label in server info view (shown after click on Info icon in countries list
  public static var torServer: String { return Localizable.tr("Localizable", "_tor_server", fallback: "Tor Server") }
  /// Tor
  public static var torTitle: String { return Localizable.tr("Localizable", "_tor_title", fallback: "Tor") }
  /// In case Proton sites are blocked, this setting allows the app to try alternative network routing to reach Proton, which can be useful for bypassing firewalls or network issues. We recommend keeping this setting on for greater reliability. 
  /// Learn more
  public static var troubleshootItemAltDescription: String { return Localizable.tr("Localizable", "_troubleshoot_item_alt_description", fallback: "In case Proton sites are blocked, this setting allows the app to try alternative network routing to reach Proton, which can be useful for bypassing firewalls or network issues. We recommend keeping this setting on for greater reliability. \nLearn more") }
  /// Learn more
  public static var troubleshootItemAltLink1: String { return Localizable.tr("Localizable", "_troubleshoot_item_alt_link1", fallback: "Learn more") }
  /// Allow alternative routing
  public static var troubleshootItemAltTitle: String { return Localizable.tr("Localizable", "_troubleshoot_item_alt_title", fallback: "Allow alternative routing") }
  /// Temporarily disable or remove your antivirus software.
  public static var troubleshootItemAntivirusDescription: String { return Localizable.tr("Localizable", "_troubleshoot_item_antivirus_description", fallback: "Temporarily disable or remove your antivirus software.") }
  /// Antivirus interference
  public static var troubleshootItemAntivirusTitle: String { return Localizable.tr("Localizable", "_troubleshoot_item_antivirus_title", fallback: "Antivirus interference") }
  /// Your country may be blocking access to Proton. Try using Tor to access Proton.
  public static var troubleshootItemGovDescription: String { return Localizable.tr("Localizable", "_troubleshoot_item_gov_description", fallback: "Your country may be blocking access to Proton. Try using Tor to access Proton.") }
  /// Tor
  public static var troubleshootItemGovLink1: String { return Localizable.tr("Localizable", "_troubleshoot_item_gov_link1", fallback: "Tor") }
  /// Government block
  public static var troubleshootItemGovTitle: String { return Localizable.tr("Localizable", "_troubleshoot_item_gov_title", fallback: "Government block") }
  /// Try connecting to Proton from a different network (or Tor).
  public static var troubleshootItemIspDescription: String { return Localizable.tr("Localizable", "_troubleshoot_item_isp_description", fallback: "Try connecting to Proton from a different network (or Tor).") }
  /// Tor
  public static var troubleshootItemIspLink1: String { return Localizable.tr("Localizable", "_troubleshoot_item_isp_link1", fallback: "Tor") }
  /// Internet Service Provider (ISP) problem
  public static var troubleshootItemIspTitle: String { return Localizable.tr("Localizable", "_troubleshoot_item_isp_title", fallback: "Internet Service Provider (ISP) problem") }
  /// Please make sure that your internet connection is working.
  public static var troubleshootItemNointernetDescription: String { return Localizable.tr("Localizable", "_troubleshoot_item_nointernet_description", fallback: "Please make sure that your internet connection is working.") }
  /// No internet connection
  public static var troubleshootItemNointernetTitle: String { return Localizable.tr("Localizable", "_troubleshoot_item_nointernet_title", fallback: "No internet connection") }
  /// Contact us directly through our support form, email (%@), or Twitter.
  public static func troubleshootItemOtherDescription(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_troubleshoot_item_other_description", String(describing: p1), fallback: "Contact us directly through our support form, email (%@), or Twitter.")
  }
  /// support form
  public static var troubleshootItemOtherLink1: String { return Localizable.tr("Localizable", "_troubleshoot_item_other_link1", fallback: "support form") }
  /// email
  public static var troubleshootItemOtherLink2: String { return Localizable.tr("Localizable", "_troubleshoot_item_other_link2", fallback: "email") }
  /// Twitter
  public static var troubleshootItemOtherLink3: String { return Localizable.tr("Localizable", "_troubleshoot_item_other_link3", fallback: "Twitter") }
  /// Still can’t find a solution
  public static var troubleshootItemOtherTitle: String { return Localizable.tr("Localizable", "_troubleshoot_item_other_title", fallback: "Still can’t find a solution") }
  /// Check Proton Status for our system status.
  public static var troubleshootItemProtonDescription: String { return Localizable.tr("Localizable", "_troubleshoot_item_proton_description", fallback: "Check Proton Status for our system status.") }
  /// Proton Status
  public static var troubleshootItemProtonLink1: String { return Localizable.tr("Localizable", "_troubleshoot_item_proton_link1", fallback: "Proton Status") }
  /// Proton is down
  public static var troubleshootItemProtonTitle: String { return Localizable.tr("Localizable", "_troubleshoot_item_proton_title", fallback: "Proton is down") }
  /// Disable any proxies or firewalls, or contact your network administrator.
  public static var troubleshootItemProxyDescription: String { return Localizable.tr("Localizable", "_troubleshoot_item_proxy_description", fallback: "Disable any proxies or firewalls, or contact your network administrator.") }
  /// Proxy/Firewall interference
  public static var troubleshootItemProxyTitle: String { return Localizable.tr("Localizable", "_troubleshoot_item_proxy_title", fallback: "Proxy/Firewall interference") }
  /// Title of connection troubleshooting screen
  public static var troubleshootTitle: String { return Localizable.tr("Localizable", "_troubleshoot_title", fallback: "Troubleshooting") }
  /// MacOS: button in connecting overlay
  public static var tryAgain: String { return Localizable.tr("Localizable", "_try_again", fallback: "Try again") }
  /// Disable kill switch and retry
  public static var tryAgainWithoutKillswitch: String { return Localizable.tr("Localizable", "_try_again_without_killswitch", fallback: "Disable kill switch and retry") }
  /// Description text of alert shown if user tries to enable both KillSwitch and Allow LAN
  public static var turnKsOnDescription: String { return Localizable.tr("Localizable", "_turn_ks_on_description", fallback: "By activating kill switch, you won't be able to access devices on your local network. \n\nContinue?") }
  /// Title of alert shown if user tries to enable both KillSwitch and Allow LAN
  public static var turnKsOnTitle: String { return Localizable.tr("Localizable", "_turn_ks_on_title", fallback: "Turn kill switch on?") }
  /// Turn on
  public static var turnOn: String { return Localizable.tr("Localizable", "_turn_on", fallback: "Turn on") }
  /// iOS Settings -> Protocol -> OpenVPN/WireGuard: UDP option
  public static var udp: String { return Localizable.tr("Localizable", "_udp", fallback: "UDP") }
  /// Common word
  public static var unavailable: String { return Localizable.tr("Localizable", "_unavailable", fallback: "Unavailable") }
  /// MacOS: Settings -> General: name of field.
  public static var unprotectedNetwork: String { return Localizable.tr("Localizable", "_unprotected_network", fallback: "Notify unprotected networks") }
  /// MacOS: Settings -> General: description
  public static var unprotectedNetworkTooltip: String { return Localizable.tr("Localizable", "_unprotected_network_tooltip", fallback: "Receive a notification when Proton VPN detects you are connected to an unprotected network.") }
  /// Insecure WiFi connection detected
  public static var unsecureWifi: String { return Localizable.tr("Localizable", "_unsecure_wifi", fallback: "Insecure WiFi connection detected") }
  /// Learn More
  public static var unsecureWifiLearnMore: String { return Localizable.tr("Localizable", "_unsecure_wifi_learn_more", fallback: "Learn More") }
  /// Insecure WiFi Detected
  public static var unsecureWifiTitle: String { return Localizable.tr("Localizable", "_unsecure_wifi_title", fallback: "Insecure WiFi Detected") }
  /// UPDATE MY BILLING
  public static var updateBilling: String { return Localizable.tr("Localizable", "_update_billing", fallback: "UPDATE MY BILLING") }
  /// Update required
  public static var updateRequired: String { return Localizable.tr("Localizable", "_update_required", fallback: "Update required") }
  /// This version of Proton VPN is no longer supported, please update the app to continue using it.
  public static var updateRequiredNoLongerSupported: String { return Localizable.tr("Localizable", "_update_required_no_longer_supported", fallback: "This version of Proton VPN is no longer supported, please update the app to continue using it.") }
  /// Secondary button title in the App update required alert
  public static var updateRequiredSupport: String { return Localizable.tr("Localizable", "_update_required_support", fallback: "Contact support") }
  /// Primary button title in the App update required alert
  public static var updateRequiredUpdate: String { return Localizable.tr("Localizable", "_update_required_update", fallback: "Update") }
  /// Button in many places in both iOS and MacOS apps
  public static var upgrade: String { return Localizable.tr("Localizable", "_upgrade", fallback: "Upgrade") }
  /// UPGRADE AGAIN
  public static var upgradeAgain: String { return Localizable.tr("Localizable", "_upgrade_again", fallback: "UPGRADE AGAIN") }
  /// Main mac app menu item
  public static var upgradeForSecureCore: String { return Localizable.tr("Localizable", "_upgrade_for_secure_core", fallback: "to use Secure Core") }
  /// MacOS: Button in Upgrade screen
  public static var upgradeMyPlan: String { return Localizable.tr("Localizable", "_upgrade_my_plan", fallback: "Upgrade My Plan") }
  /// Upgrade button in trial modals used in both iOS and MacOS
  public static var upgradeNow: String { return Localizable.tr("Localizable", "_upgrade_now", fallback: "Upgrade Now") }
  /// macOS: plan upgrade required alert
  public static var upgradePlanToAccessServer: String { return Localizable.tr("Localizable", "_upgrade_plan_to_access_server", fallback: "Sorry, this server is not available for your subscription tier. If you would like to access more servers, consider upgrading your subscription.") }
  /// iOS & MacOS: text near country or server; MacOS: title of several alerts
  public static var upgradeRequired: String { return Localizable.tr("Localizable", "_upgrade_required", fallback: "Upgrade Required") }
  /// Secure Core is available with a Plus plan. Upgrade now to route traffic through our safest servers in privacy-friendly countries.
  public static var upgradeRequiredSecurecoreDescription: String { return Localizable.tr("Localizable", "_upgrade_required_securecore_description", fallback: "Secure Core is available with a Plus plan. Upgrade now to route traffic through our safest servers in privacy-friendly countries.") }
  /// iOS: Plan selection during plan upgarde, button insettings screen
  public static var upgradeSubscription: String { return Localizable.tr("Localizable", "_upgrade_subscription", fallback: "Upgrade Subscription") }
  /// Main mac app menu item
  public static var upgradeToPlus: String { return Localizable.tr("Localizable", "_upgrade_to_plus", fallback: "Upgrade to Plus") }
  /// Plan upgrade unavailable alert
  public static var upgradeUnavailableBody: String { return Localizable.tr("Localizable", "_upgrade_unavailable_body", fallback: "Your Proton VPN subscription cannot be upgraded from within the app, please visit account.protonvpn.com to upgrade.") }
  /// If the app cannot upgrade the user's plan and they must go to the website to upgrade it. Plan upgrade unavailable alert
  public static var upgradeUnavailableTitle: String { return Localizable.tr("Localizable", "_upgrade_unavailable_title", fallback: "Upgrade Unavailable in App") }
  /// Menu point in settings screen
  public static var usageStatistics: String { return Localizable.tr("Localizable", "_usage_statistics", fallback: "Usage statistics") }
  /// iOS: human verification option select button
  public static var useCaptchaVerification: String { return Localizable.tr("Localizable", "_use_captcha_verification", fallback: "Verify with CAPTCHA") }
  /// iOS: human verification option select button
  public static var useOtherEmailAddress: String { return Localizable.tr("Localizable", "_use_other_email_address", fallback: "Verify with email") }
  /// Profile create/change form
  public static var useSecureCore: String { return Localizable.tr("Localizable", "_use_secure_core", fallback: "Secure Core") }
  /// Verify with SMS
  public static var useSmsVerification: String { return Localizable.tr("Localizable", "_use_sms_verification", fallback: "Verify with SMS") }
  /// Used in sign-in, sign-up and in settings
  public static var username: String { return Localizable.tr("Localizable", "_username", fallback: "Username") }
  /// iOS: text in human verification code form
  public static var verificationInstructions: String { return Localizable.tr("Localizable", "_verification_instructions", fallback: "A verification code has been sent to you, please enter it below.") }
  /// iOS setting: after this word actual version and build number are appended
  public static var version: String { return Localizable.tr("Localizable", "_version", fallback: "Version") }
  /// MacOS: About window
  public static var versionCurrent: String { return Localizable.tr("Localizable", "_version_current", fallback: "Current version:") }
  /// Used in several places in iOS to make SecureCore server description, similar to 'viaCountry' translation
  public static var via: String { return Localizable.tr("Localizable", "_via", fallback: "via") }
  /// Used for SecureCore connection labels. %@ is a country e.g. via Switzerland
  public static func viaCountry(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_via_country", String(describing: p1), fallback: "via %@")
  }
  /// MacOS menu item; iOS setting screen item
  public static var viewLogs: String { return Localizable.tr("Localizable", "_view_logs", fallback: "View Logs") }
  /// Text in warning screen before actions that will disconnect VPN
  public static var viewToggleWillCauseDisconnect: String { return Localizable.tr("Localizable", "_view_toggle_will_cause_disconnect", fallback: "Toggling Secure Core will end your current connection.") }
  /// Change VPN Accelerator
  public static var vpnAcceleratorChangeTitle: String { return Localizable.tr("Localizable", "_vpn_accelerator_change_title", fallback: "Change VPN Accelerator") }
  /// Tooltip on Connection Settings for Accelerator toggle, we temporary added a second % at the end of the string to avoid a SwiftGen error that removes single % characters, should be replaced in all languages
  public static var vpnAcceleratorDescription: String { return Localizable.tr("Localizable", "_vpn_accelerator_description", fallback: "VPN Accelerator enables a set of unique performance enhancing technologies which can increase VPN speeds by up to 400%%.\nLearn more") }
  /// Link with more info in the VPN Accelerator description
  public static var vpnAcceleratorDescriptionAltLink: String { return Localizable.tr("Localizable", "_vpn_accelerator_description_alt_link", fallback: "Learn more") }
  /// VPN Accelerator
  public static var vpnAcceleratorTitle: String { return Localizable.tr("Localizable", "_vpn_accelerator_title", fallback: "VPN Accelerator") }
  /// MacOS: alert before disconnection on protocol and/or SecureCore state change
  public static var vpnConnectionActive: String { return Localizable.tr("Localizable", "_vpn_connection_active", fallback: "VPN Connection Active") }
  /// iOS Settings -> Protocol: screen title
  public static var vpnProtocol: String { return Localizable.tr("Localizable", "_vpn_protocol", fallback: "VPN Protocol") }
  /// User is trying to switch to a VPN protocol that isn't supported on the current server (text)
  public static var vpnProtocolNotSupportedText: String { return Localizable.tr("Localizable", "_vpn_protocol_not_supported_text", fallback: "The VPN protocol is not available for the connection you have selected. To connect, try changing the protocol or server.") }
  /// User is trying to switch to a VPN protocol that isn't supported on the current server (title)
  public static var vpnProtocolNotSupportedTitle: String { return Localizable.tr("Localizable", "_vpn_protocol_not_supported_title", fallback: "VPN Protocol Not Supported") }
  /// VPN stuck alert
  public static var vpnStuckDisconnectingBody: String { return Localizable.tr("Localizable", "_vpn_stuck_disconnecting_body", fallback: "Your device failed to terminate a previous VPN session. You will need to restart your device before you can establish a new VPN connection.") }
  /// VPN stuck alert
  public static var vpnStuckDisconnectingTitle: String { return Localizable.tr("Localizable", "_vpn_stuck_disconnecting_title", fallback: "Connection error") }
  /// Failed to refresh VPN certificate. Please check your connection
  public static var vpnauthCertfailDescription: String { return Localizable.tr("Localizable", "_vpnauth_certfail_description", fallback: "Failed to refresh VPN certificate. Please check your connection") }
  /// Authentication error
  public static var vpnauthCertfailTitle: String { return Localizable.tr("Localizable", "_vpnauth_certfail_title", fallback: "Authentication error") }
  /// You reached the maximum number of setting changes. Please try again in a few minutes
  public static var vpnauthTooManyCertsDescription: String { return Localizable.tr("Localizable", "_vpnauth_too_many_certs_description", fallback: "You reached the maximum number of setting changes. Please try again in a few minutes") }
  /// Plural format key: "%#@VARIABLE@"
  public static func vpnauthTooManyCertsRetryAfter(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "_vpnauth_too_many_certs_retry_after", p1, fallback: "Plural format key: \"%#@VARIABLE@\"")
  }
  /// Authentication error
  public static var vpnauthTooManyCertsTitle: String { return Localizable.tr("Localizable", "_vpnauth_too_many_certs_title", fallback: "Authentication error") }
  /// You are not signed in to Proton VPN. Open the Proton VPN app and sign in.
  public static var vpnstatusNotLoggedin: String { return Localizable.tr("Localizable", "_vpnstatus_not_loggedin", fallback: "You are not signed in to Proton VPN. Open the Proton VPN app and sign in.") }
  /// Used as a title in alerts/modals
  public static var warning: String { return Localizable.tr("Localizable", "_warning", fallback: "Warning") }
  /// MacOS: alert shown during login if already connected to VPN
  public static var warningVpnSessionIsActive: String { return Localizable.tr("Localizable", "_warning_vpn_session_is_active", fallback: "Another user's Proton VPN session is active on this device. Continuing with the sign in will cause the current session to end. Do you want to continue?") }
  /// Shown on the Welcome screen as the longer screen text
  public static var welcomeBody: String { return Localizable.tr("Localizable", "_welcome_body", fallback: "High-speed Swiss VPN that safeguards your privacy by encrypting your internet connection.") }
  /// Thanks for using Proton VPN.
  public static var welcomeDescription: String { return Localizable.tr("Localizable", "_welcome_description", fallback: "Thanks for using Proton VPN.") }
  /// Shown on the Welcome screen as the screen headline
  public static var welcomeHeadline: String { return Localizable.tr("Localizable", "_welcome_headline", fallback: "Protect yourself online") }
  /// MacOS welcome screen: title
  public static var welcomeTitle: String { return Localizable.tr("Localizable", "_welcome_title", fallback: "WELCOME ON BOARD!") }
  /// Also used for disabling kill switch in the 'NetworkExtension + KillSwitch on T2 Macs' case below
  public static var wgksKsOff: String { return Localizable.tr("Localizable", "_wgks_ks_off", fallback: "Disable kill switch") }
  /// iOS: 1. Menu point in settings screen. 2. Widget description screen title.
  public static var widget: String { return Localizable.tr("Localizable", "_widget", fallback: "iOS Widget") }
  /// iOS Settings -> Protocol: WireGuard option
  public static var wireguard: String { return Localizable.tr("Localizable", "_wireguard", fallback: "WireGuard") }
  /// iOS Settings: WireGuard logs row
  public static var wireguardLogs: String { return Localizable.tr("Localizable", "_wireguard_logs", fallback: "WireGuard Logs") }
  /// Settings -> Protocol: WireGuard TLS Option called "Stealth". Should not be translated.
  public static var wireguardTls: String { return Localizable.tr("Localizable", "_wireguard_tls", fallback: "Stealth") }
  /// Subtitle of banner shown on iOS apps to upsell users who want to select a country
  public static var wrongCountryBannerSubtitle: String { return Localizable.tr("Localizable", "_wrong_country_banner_subtitle", fallback: "Upgrade to choose any server") }
  /// Text of banner shown on macOS apps to upsell users who want to select a country
  public static var wrongCountryBannerText: String { return Localizable.tr("Localizable", "_wrong_country_banner_text", fallback: "Not the country you wanted? Upgrade to choose any server") }
  /// Title of banner shown on iOS apps to upsell users who want to select a country
  public static var wrongCountryBannerTitle: String { return Localizable.tr("Localizable", "_wrong_country_banner_title", fallback: "Not the country you wanted?") }
  /// MacOS: text in main window
  public static var youAreNotConnected: String { return Localizable.tr("Localizable", "_you_are_not_connected", fallback: "You are not connected") }
  /// Button to apply coupon
  public static var applyCoupon: String { return Localizable.tr("Localizable", "apply_coupon", fallback: "Apply") }
  /// Button to confirm two-factor or recovery code in login
  public static var authenticate: String { return Localizable.tr("Localizable", "authenticate", fallback: "Authenticate") }
  /// Connection status title when user is connected to a VPN [Redesign_2023]
  public static var connectionStatusProtected: String { return Localizable.tr("Localizable", "connection_status_protected", fallback: "Protected") }
  /// Connection status title when user is initiating connection to a VPN [Redesign_2023]
  public static var connectionStatusProtecting: String { return Localizable.tr("Localizable", "connection_status_protecting", fallback: "Protecting your digital identity") }
  /// Connection status title when user is not connected to a VPN [Redesign_2023]
  public static var connectionStatusUnprotected: String { return Localizable.tr("Localizable", "connection_status_unprotected", fallback: "You are unprotected") }
  /// Banner shown after coupon is applied
  public static var couponApplied: String { return Localizable.tr("Localizable", "coupon_applied", fallback: "Coupon has been applied successfully.") }
  /// Banner shown after coupon is applied but the plan is not yet upgraded
  public static var couponAppliedPlanNotUpgradedYet: String { return Localizable.tr("Localizable", "coupon_applied_plan_not_upgraded_yet", fallback: "Coupon has been applied successfully. Your subscription will be upgraded within a few minutes.") }
  /// Title of the screen to apply a coupon
  public static var couponCode: String { return Localizable.tr("Localizable", "coupon_code", fallback: "Coupon code") }
  /// Modal that lists countries in which servers are available to free users: banner with CTA
  public static var freeConnectionsModalBanner: String { return Localizable.tr("Localizable", "free_connections_modal_banner", fallback: "Get worldwide coverage with VPN Plus") }
  /// Modal that lists countries in which servers are available to free users: Description
  public static var freeConnectionsModalDescription: String { return Localizable.tr("Localizable", "free_connections_modal_description", fallback: "Proton Free automatically connects you to the fastest available server. This will normally be the closest server to your location.") }
  /// Plural format key: "%#@VARIABLE@"
  public static func freeConnectionsModalSubtitle(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "free_connections_modal_subtitle", p1, fallback: "Plural format key: \"%#@VARIABLE@\"")
  }
  /// Modal that lists countries in which servers are available to free users: Title
  public static var freeConnectionsModalTitle: String { return Localizable.tr("Localizable", "free_connections_modal_title", fallback: "Free connections") }
  /// Configuring your VPN access
  public static var loginFetchVpnData: String { return Localizable.tr("Localizable", "login_fetch_vpn_data", fallback: "Configuring your VPN access") }
  /// Start using Proton VPN
  public static var loginSummaryButton: String { return Localizable.tr("Localizable", "login_summary_button", fallback: "Start using Proton VPN") }
  /// Error message shown when tryng to log in with an unsupported method
  public static var loginUnsupportedState: String { return Localizable.tr("Localizable", "login_unsupported_state", fallback: "Invalid login method. Please contact support.") }
  /// Description of user account update screen
  public static var maximumDeviceLimit: String { return Localizable.tr("Localizable", "maximum_device_limit", fallback: "Please disconnect another device to connect to this one.") }
  /// Description of user account update screen part 1
  public static func maximumDevicePlanLimitPart1(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "maximum_device_plan_limit_part_1", String(describing: p1), fallback: "Please disconnect another device to connect to this one or upgrade to %@")
  }
  /// Plural format key: " to get up to %#@num_devices@ connected at the same time."
  public static func maximumDevicePlanLimitPart2(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "maximum_device_plan_limit_part_2", p1, fallback: "Plural format key: \" to get up to %#@num_devices@ connected at the same time.\"")
  }
  /// Common button title
  public static var modalsCommonCancel: String { return Localizable.tr("Localizable", "modals_common_cancel", fallback: "Cancel") }
  /// Common button title
  public static var modalsCommonGetStarted: String { return Localizable.tr("Localizable", "modals_common_get_started", fallback: "Get started") }
  /// Common button title
  public static var modalsCommonLearnMore: String { return Localizable.tr("Localizable", "modals_common_learn_more", fallback: "Learn more") }
  /// Common button title
  public static var modalsCommonNext: String { return Localizable.tr("Localizable", "modals_common_next", fallback: "Next") }
  /// Positive user action on Secure Core discouragement screen
  public static var modalsDiscourageSecureCoreActivate: String { return Localizable.tr("Localizable", "modals_discourage_secure_core_activate", fallback: "Activate Secure Core") }
  /// Turn off Secure Core discouragement screen
  public static var modalsDiscourageSecureCoreDontShow: String { return Localizable.tr("Localizable", "modals_discourage_secure_core_dont_show", fallback: "Don’t show again") }
  /// Subtitle of the Secure Core discouragement screen
  public static var modalsDiscourageSecureCoreSubtitle: String { return Localizable.tr("Localizable", "modals_discourage_secure_core_subtitle", fallback: "Secure Core offers the highest level of security and privacy, but it may reduce your internet speed. If you need more performance, you can disable Secure Core.") }
  /// Title of the Secure Core discouragement screen
  public static var modalsDiscourageSecureCoreTitle: String { return Localizable.tr("Localizable", "modals_discourage_secure_core_title", fallback: "A note about speed...") }
  /// Title of the first section of the "What's new" screen
  public static var modalsFreeCountries: String { return Localizable.tr("Localizable", "modals_free_countries", fallback: "New Free countries") }
  /// Upgrade plan button title
  public static var modalsGetPlus: String { return Localizable.tr("Localizable", "modals_get_plus", fallback: "Upgrade") }
  /// Description of the first section of the "What's new" screen
  public static var modalsNewServers: String { return Localizable.tr("Localizable", "modals_new_servers", fallback: "There are now Free servers in Poland and Romania.") }
  /// Description of the second section of the "What's new" screen
  public static var modalsServerCrowding: String { return Localizable.tr("Localizable", "modals_server_crowding", fallback: "To prevent server crowding and ensure that everyone has access to fast and secure browsing, we removed manual country selection and made major improvements to automatic server selection.") }
  /// Title of the second section of the "What's new" screen
  public static var modalsServerSelection: String { return Localizable.tr("Localizable", "modals_server_selection", fallback: "Changes to server selection") }
  /// Feature of the All Countries upsell screen
  public static var modalsUpsellAllCountriesFeatureHighSpeed: String { return Localizable.tr("Localizable", "modals_upsell_all_countries_feature_highSpeed", fallback: "Browse at the highest speeds (10 Gbps)") }
  /// Plural format key: "%#@VARIABLE@"
  public static func modalsUpsellAllCountriesFeatureMultipleDevices(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "modals_upsell_all_countries_feature_multipleDevices", p1, fallback: "Plural format key: \"%#@VARIABLE@\"")
  }
  /// Feature of the All Countries upsell screen
  public static var modalsUpsellAllCountriesFeatureNetshield: String { return Localizable.tr("Localizable", "modals_upsell_all_countries_feature_netshield", fallback: "Block ads and malware with NetShield") }
  /// Feature of the All Countries upsell screen
  public static var modalsUpsellAllCountriesFeatureStreaming: String { return Localizable.tr("Localizable", "modals_upsell_all_countries_feature_streaming", fallback: "Stream your favorite movies") }
  /// Plural format key: "Access over %#@num_servers@ in %#@num_countries@"
  public static func modalsUpsellAllCountriesTitle(_ p1: Int, _ p2: Int) -> String {
    return Localizable.tr("Localizable", "modals_upsell_all_countries_title", p1, p2, fallback: "Plural format key: \"Access over %#@num_servers@ in %#@num_countries@\"")
  }
  /// Feature of the Moderate NAT upsell screen
  public static var modalsUpsellFeaturesModerateNatDirectConnections: String { return Localizable.tr("Localizable", "modals_upsell_features_moderate_nat_direct_connections", fallback: "NAT type 2 (moderate) optimizes speed and stability by enabling direct connections between devices") }
  /// Feature of the Moderate NAT upsell screen
  public static var modalsUpsellFeaturesModerateNatGaming: String { return Localizable.tr("Localizable", "modals_upsell_features_moderate_nat_gaming", fallback: "Improve online gaming and video call performance") }
  /// Subtitle of the Safe Mode upsell screen
  public static var modalsUpsellFeaturesSafeModeSubtitle: String { return Localizable.tr("Localizable", "modals_upsell_features_safe_mode_subtitle", fallback: "Have advanced or professional computing needs that require non-standard ports?\n\nUpgrade to VPN Plus to access this and other premium features.") }
  /// Subtitle of All Countries, NetShield and Secure Core upsell screens
  public static var modalsUpsellFeaturesSubtitle: String { return Localizable.tr("Localizable", "modals_upsell_features_subtitle", fallback: "When you upgrade to Plus") }
  /// Subtitle of Moderate NAT upsell screens
  public static var modalsUpsellModerateNatSubtitle: String { return Localizable.tr("Localizable", "modals_upsell_moderate_nat_subtitle", fallback: "Unlock NAT type 2 with VPN Plus") }
  /// Bold part of the subtitle of Moderate NAT upsell screens
  public static var modalsUpsellModerateNatSubtitleBold: String { return Localizable.tr("Localizable", "modals_upsell_moderate_nat_subtitle_bold", fallback: "NAT type 2") }
  /// Title of the Moderate NAT upsell screen
  public static var modalsUpsellModerateNatTitle: String { return Localizable.tr("Localizable", "modals_upsell_moderate_nat_title", fallback: "Level up your gaming experience") }
  /// Feature of the NetShield upsell screen
  public static var modalsUpsellNetShieldAds: String { return Localizable.tr("Localizable", "modals_upsell_net_shield_ads", fallback: "Block ads and trackers") }
  /// Feature of the NetShield upsell screen
  public static var modalsUpsellNetShieldHighSpeed: String { return Localizable.tr("Localizable", "modals_upsell_net_shield_highSpeed", fallback: "Browse at the highest speeds") }
  /// Feature of the NetShield upsell screen
  public static var modalsUpsellNetShieldMalware: String { return Localizable.tr("Localizable", "modals_upsell_net_shield_malware", fallback: "Protect your device from malware") }
  /// Title of the NetShield upsell screen
  public static var modalsUpsellNetShieldTitle: String { return Localizable.tr("Localizable", "modals_upsell_net_shield_title", fallback: "Enjoy ad-free browsing with NetShield") }
  /// Title of the Safe Mode upsell screen
  public static var modalsUpsellSafeModeTitle: String { return Localizable.tr("Localizable", "modals_upsell_safe_mode_title", fallback: "Allow traffic to non-standard ports") }
  /// Feature of the Secure Core upsell screen
  public static var modalsUpsellSecureCoreAttacks: String { return Localizable.tr("Localizable", "modals_upsell_secure_core_attacks", fallback: "Protect yourself from network attacks") }
  /// Feature of the Secure Core upsell screen
  public static var modalsUpsellSecureCoreLayer: String { return Localizable.tr("Localizable", "modals_upsell_secure_core_layer", fallback: "Add another layer of encryption to your VPN connection") }
  /// Feature of the Secure Core upsell screen
  public static var modalsUpsellSecureCoreRoute: String { return Localizable.tr("Localizable", "modals_upsell_secure_core_route", fallback: "Route through ultra secure servers in Switzerland, Sweden, and Iceland") }
  /// Title of the Secure Core upsell screen
  public static var modalsUpsellSecureCoreTitle: String { return Localizable.tr("Localizable", "modals_upsell_secure_core_title", fallback: "Double the encryption with Secure Core") }
  /// Dismiss upsell screen button title
  public static var modalsUpsellStayFree: String { return Localizable.tr("Localizable", "modals_upsell_stay_free", fallback: "Not now") }
  /// Title of the "What's new" screen
  public static var modalsWhatsNew: String { return Localizable.tr("Localizable", "modals_whats_new", fallback: "What’s new") }
  /// The hint that appears on mac when user hovers with a mouse over the value of netshield stats - advertisements blocked
  public static var netshieldStatsHintAds: String { return Localizable.tr("Localizable", "netshield_stats_hint_ads", fallback: "Advertisement websites use cookies and trackers to target you.") }
  /// The hint that appears on mac when user hovers with a mouse over the value of netshield stats - data saved
  public static var netshieldStatsHintData: String { return Localizable.tr("Localizable", "netshield_stats_hint_data", fallback: "Estimated size of ads, trackers, and malware that NetShield has blocked.") }
  /// The hint that appears on mac when user hovers with a mouse over the value of netshield stats - trackers stopped
  public static var netshieldStatsHintTrackers: String { return Localizable.tr("Localizable", "netshield_stats_hint_trackers", fallback: "Trackers are third-party websites that collect, store, and sell information about your web activity.") }
  /// Title of "done" button in New Brand screen
  public static var newPlansBrandGotIt: String { return Localizable.tr("Localizable", "new_plans_brand_got_it", fallback: "Got it") }
  /// Subtitle of the New Brand screen
  public static var newPlansBrandSubtitle: String { return Localizable.tr("Localizable", "new_plans_brand_subtitle", fallback: "Introducing Proton’s refreshed look.\nMany services, one mission. Welcome to an internet where privacy is the default.") }
  /// Title of the New Brand screen
  public static var newPlansBrandTitle: String { return Localizable.tr("Localizable", "new_plans_brand_title", fallback: "Updated Proton, unified protection") }
  /// Crash reports help us fix bugs, detect firewalls, and avoid VPN blocks.
  public static var onboardingCrashReportsDescription: String { return Localizable.tr("Localizable", "onboarding_crash_reports_description", fallback: "Crash reports help us fix bugs, detect firewalls, and avoid VPN blocks.") }
  /// Share anonymous crash reports
  public static var onboardingCrashReportsTitle: String { return Localizable.tr("Localizable", "onboarding_crash_reports_title", fallback: "Share anonymous crash reports") }
  /// These statistics do not contain your IP address, and they cannot be used to identify you. We'll never share them with third parties.
  public static var onboardingFooter: String { return Localizable.tr("Localizable", "onboarding_footer", fallback: "These statistics do not contain your IP address, and they cannot be used to identify you. We'll never share them with third parties.") }
  /// Learn more
  public static var onboardingFooterLearnMore: String { return Localizable.tr("Localizable", "onboarding_footer_learn_more", fallback: "Learn more") }
  /// Usage data helps us overcome VPN blocks and improve app performance.
  public static var onboardingUsageStatsDescription: String { return Localizable.tr("Localizable", "onboarding_usage_stats_description", fallback: "Usage data helps us overcome VPN blocks and improve app performance.") }
  /// Share anonymous usage statistics
  public static var onboardingUsageStatsTitle: String { return Localizable.tr("Localizable", "onboarding_usage_stats_title", fallback: "Share anonymous usage statistics") }
  /// Error message shown when the user clicks Create Account in the macOS app but the Proton website is not reachable
  public static var protonWebsiteUnreachable: String { return Localizable.tr("Localizable", "proton_website_unreachable", fallback: "The Proton VPN website might be temporarily unreachable due to network restrictions. Please use the mobile app to create a new Proton account.") }
  /// Placeholder for the Recovery code text field
  public static var recoveryCode: String { return Localizable.tr("Localizable", "recovery_code", fallback: "Recovery code") }
  /// Placeholder text showing in the search bar on the search screen
  public static var searchBarPlaceholder: String { return Localizable.tr("Localizable", "search_bar_placeholder", fallback: "Country, City or Server") }
  /// Section header in search
  public static var searchCities: String { return Localizable.tr("Localizable", "search_cities", fallback: "Cities") }
  /// Sample cities the user can search for
  public static var searchCitiesSample: String { return Localizable.tr("Localizable", "search_cities_sample", fallback: "New York, London, Tokyo...") }
  /// Section header in search
  public static var searchCountries: String { return Localizable.tr("Localizable", "search_countries", fallback: "Countries") }
  /// Sample countries the user can search for
  public static var searchCountriesSample: String { return Localizable.tr("Localizable", "search_countries_sample", fallback: "Switzerland, United States, Italy...") }
  /// Subtitle shown when nothing is found in search
  public static var searchNoResultsSubtitle: String { return Localizable.tr("Localizable", "search_no_results_subtitle", fallback: "Please try a different keyword") }
  /// Title shown when nothing is found in search
  public static var searchNoResultsTitle: String { return Localizable.tr("Localizable", "search_no_results_title", fallback: "No results found") }
  /// Button to clear recent searches history
  public static var searchRecentClear: String { return Localizable.tr("Localizable", "search_recent_clear", fallback: "Clear") }
  /// Cancel button title in the alert asking for confirmation before deleting recent searches
  public static var searchRecentClearCancel: String { return Localizable.tr("Localizable", "search_recent_clear_cancel", fallback: "Cancel") }
  /// Confirmation button title in alert asking for confirmation before deleting recent searches
  public static var searchRecentClearContinue: String { return Localizable.tr("Localizable", "search_recent_clear_continue", fallback: "Continue") }
  /// Title for the alert asking for confirmation before deleting recent searches
  public static var searchRecentClearTitle: String { return Localizable.tr("Localizable", "search_recent_clear_title", fallback: "Your search history will be lost. Continue?") }
  /// Header for the recent searches section in search
  public static var searchRecentHeader: String { return Localizable.tr("Localizable", "search_recent_header", fallback: "Recently viewed") }
  /// Section header in search
  public static var searchResultsCities: String { return Localizable.tr("Localizable", "search_results_cities", fallback: "Cities") }
  /// Section header in search
  public static var searchResultsCountries: String { return Localizable.tr("Localizable", "search_results_countries", fallback: "Countries") }
  /// Section header in search
  public static var searchSecureCoreCountries: String { return Localizable.tr("Localizable", "search_secure_core_countries", fallback: "Secure Core countries") }
  /// Section header in Search
  public static var searchServers: String { return Localizable.tr("Localizable", "search_servers", fallback: "Servers") }
  /// Sample servers the user can search for
  public static var searchServersSample: String { return Localizable.tr("Localizable", "search_servers_sample", fallback: "JP#50, CA#3, IT#14...") }
  /// Title of the Search screen infographic
  public static var searchSubtitle: String { return Localizable.tr("Localizable", "search_subtitle", fallback: "Search for any location") }
  /// Title of the search screen
  public static var searchTitle: String { return Localizable.tr("Localizable", "search_title", fallback: "Search") }
  /// Subtitle for the upsell banner shown to free users in search
  public static var searchUpsellSubtitle: String { return Localizable.tr("Localizable", "search_upsell_subtitle", fallback: "More locations = more unblocked content + extra security + faster speeds") }
  /// Plural format key: "Access all %#@num_countries@"
  public static func searchUpsellTitle(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "search_upsell_title", p1, fallback: "Plural format key: \"Access all %#@num_countries@\"")
  }
  /// Section header in search
  public static var searchUsRegions: String { return Localizable.tr("Localizable", "search_us_regions", fallback: "US regions") }
  /// Sample US regions the user can search for
  public static var searchUsRegionsSample: String { return Localizable.tr("Localizable", "search_us_regions_sample", fallback: "California, Florida, Colorado...") }
  /// Plural format key: "Hundreds of servers in %#@num_countries@"
  public static func subscriptionUpgradeOption1(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "subscription_upgrade_option1", p1, fallback: "Plural format key: \"Hundreds of servers in %#@num_countries@\"")
  }
  /// Plural format key: "Connect up to %#@num_devices@ at the same time"
  public static func subscriptionUpgradeOption2(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "subscription_upgrade_option2", p1, fallback: "Plural format key: \"Connect up to %#@num_devices@ at the same time\"")
  }
  /// Title for the Two-factor authentication screen
  public static var twoFactorAuthentication: String { return Localizable.tr("Localizable", "two_factor_authentication", fallback: "Two-factor authentication") }
  /// Placeholder for the Two Factor text field
  public static var twoFactorCode: String { return Localizable.tr("Localizable", "two_factor_code", fallback: "Two-factor code") }
  /// Feature of Countries upsell modal
  public static var upsellCountriesAnyLocation: String { return Localizable.tr("Localizable", "upsell_countries_any_location", fallback: "Choose any location") }
  /// Feature of Country upsell modal
  public static func upsellCountriesConnectTo(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "upsell_countries_connect_to", p1, fallback: "Connect to %d countries")
  }
  /// Feature of Countries upsell modal
  public static var upsellCountriesEvenHigherSpeed: String { return Localizable.tr("Localizable", "upsell_countries_even_higher_speed", fallback: "Even higher VPN speed") }
  /// Feature of Countries upsell modal
  public static var upsellCountriesGeoblockedContent: String { return Localizable.tr("Localizable", "upsell_countries_geoblocked_content", fallback: "Access geoblocked content") }
  /// Feature of Country upsell modal
  public static var upsellCountriesHigherSpeeds: String { return Localizable.tr("Localizable", "upsell_countries_higher_speeds", fallback: "Even higher VPN speed") }
  /// Feature of Country upsell modal
  public static var upsellCountriesMoneyBack: String { return Localizable.tr("Localizable", "upsell_countries_money_back", fallback: "30-day money back guarantee") }
  /// Feature of Country upsell modal
  public static var upsellCountryFeatureSubtitle: String { return Localizable.tr("Localizable", "upsell_country_feature_subtitle", fallback: "Unlock country selection with VPN Plus") }
  /// Bold part of the feature of Country upsell modal
  public static var upsellCountryFeatureSubtitleBold: String { return Localizable.tr("Localizable", "upsell_country_feature_subtitle_bold", fallback: "country selection") }
  /// Feature of Country upsell modal
  public static var upsellCountryFeatureTitle: String { return Localizable.tr("Localizable", "upsell_country_feature_title", fallback: "Want to choose a specific country?") }
  /// Feature of Customization upsell modal
  public static var upsellCustomizationAccessLAN: String { return Localizable.tr("Localizable", "upsell_customization_access_LAN", fallback: "Access devices on your local area network (LAN)") }
  /// Bold part of the feature of Customization upsell modal
  public static var upsellCustomizationAccessLANBold: String { return Localizable.tr("Localizable", "upsell_customization_access_LAN_bold", fallback: "local area network (LAN)") }
  /// Feature of Customization upsell modal
  public static var upsellCustomizationProfiles: String { return Localizable.tr("Localizable", "upsell_customization_profiles", fallback: "Save frequently used connections with profiles") }
  /// Bold part of the feature of Customization upsell modal
  public static var upsellCustomizationProfilesBold: String { return Localizable.tr("Localizable", "upsell_customization_profiles_bold", fallback: "profiles") }
  /// Feature of Customization upsell modal
  public static var upsellCustomizationQuickConnect: String { return Localizable.tr("Localizable", "upsell_customization_quick_connect", fallback: "Get faster access to your profiles with Quick Connect") }
  /// Bold part of the feature of Customization upsell modal
  public static var upsellCustomizationQuickConnectBold: String { return Localizable.tr("Localizable", "upsell_customization_quick_connect_bold", fallback: "Quick Connect") }
  /// Title of Customization upsell modal
  public static var upsellCustomizationTitle: String { return Localizable.tr("Localizable", "upsell_customization_title", fallback: "Unlock advanced VPN customization") }
  /// Button title when user is on lower tier than the server requires [Redesign_2023]
  public static var upsellGetPlus: String { return Localizable.tr("Localizable", "upsell_get_plus", fallback: "Get Plus") }
  /// Feature of Profiles upsell modal
  public static var upsellProfilesFeatureAutoConnect: String { return Localizable.tr("Localizable", "upsell_profiles_feature_auto_connect", fallback: "Set up auto-connect for even faster access.") }
  /// Feature of Profiles upsell modal
  public static var upsellProfilesFeatureLocation: String { return Localizable.tr("Localizable", "upsell_profiles_feature_location", fallback: "Save your preferred server, city, or country.") }
  /// Feature of Profiles upsell modal
  public static var upsellProfilesFeatureProtocols: String { return Localizable.tr("Localizable", "upsell_profiles_feature_protocols", fallback: "Set custom protocols and premium VPN features.") }
  /// Subtitle of Profiles upsell modal
  public static var upsellProfilesSubtitle: String { return Localizable.tr("Localizable", "upsell_profiles_subtitle", fallback: "Unlock profiles with VPN Plus") }
  /// Bold part of the subtitle of Profiles upsell modal
  public static var upsellProfilesSubtitleBold: String { return Localizable.tr("Localizable", "upsell_profiles_subtitle_bold", fallback: "profiles") }
  /// Title of Profiles upsell modal
  public static var upsellProfilesTitle: String { return Localizable.tr("Localizable", "upsell_profiles_title", fallback: "Get quick access to your frequent connections") }
  /// The button text that will appear when the user has waited for the countdown and can proceed without upgrading.
  public static var upsellSpecificLocationChangeServerButtonTitle: String { return Localizable.tr("Localizable", "upsell_specific_location_change_server_button_title", fallback: "Change server") }
  /// Displayed when the user clicks "Connect to Random Server" after they've just clicked it.
  public static var upsellSpecificLocationSubtitle: String { return Localizable.tr("Localizable", "upsell_specific_location_subtitle", fallback: "Get unlimited changes with VPN Plus") }
  /// Displayed when the user clicks "Connect to Random Server" too many times in a given time interval.
  public static var upsellSpecificLocationTitle: String { return Localizable.tr("Localizable", "upsell_specific_location_title", fallback: "You've reached the maximum number of Free server changes for now.") }
  /// Feature of VPN Accelerator upsell modal
  public static var upsellVpnAcceleratorDistantServers: String { return Localizable.tr("Localizable", "upsell_vpn_accelerator_distant_servers", fallback: "Improved speed and stability when connected to distant servers.") }
  /// Feature of VPN Accelerator upsell modal
  public static var upsellVpnAcceleratorFasterServers: String { return Localizable.tr("Localizable", "upsell_vpn_accelerator_faster_servers", fallback: "Access faster, less crowded servers.") }
  /// Feature of VPN Accelerator upsell modal
  public static var upsellVpnAcceleratorIncreaseConnectionSpeeds: String { return Localizable.tr("Localizable", "upsell_vpn_accelerator_increase_connection_speeds", fallback: "Increase connection speeds by up to 400%% with VPN Accelerator.") }
  /// Bold part of the feature of VPN Accelerator upsell modal
  public static var upsellVpnAcceleratorIncreaseConnectionSpeedsBold: String { return Localizable.tr("Localizable", "upsell_vpn_accelerator_increase_connection_speeds_bold", fallback: "VPN Accelerator.") }
  /// Title of VPN Accelerator upsell modal
  public static var upsellVpnAcceleratorTitle: String { return Localizable.tr("Localizable", "upsell_vpn_accelerator_title", fallback: "Browse at even higher speeds (up to 10 Gbps)") }
  /// Title of the Use coupon button in Settings
  public static var useCoupon: String { return Localizable.tr("Localizable", "use_coupon", fallback: "Use coupon") }
  /// Title for the button to switch to entering recovery code
  public static var useRecoveryCode: String { return Localizable.tr("Localizable", "use_recovery_code", fallback: "Use recovery code") }
  /// Title for the button to switch to entering two-factor code
  public static var useTwoFactorCode: String { return Localizable.tr("Localizable", "use_two_factor_code", fallback: "Use two-factor code") }
  /// Error message shown when setting a VPN feature like VPN Accelerator is not possible at the moment
  public static func vpnFeatureCannotBeSetError(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "vpn_feature_cannot_be_set_error", String(describing: p1), fallback: "%@ setting could not be changed. Please try again later or connect to a different server")
  }
  /// Plural format key: "Up to %#@VARIABLE@ at once"
  public static func welcomeScreenFeatureDevices(_ p1: Int) -> String {
    return Localizable.tr("Localizable", "welcome_screen_feature_devices", p1, fallback: "Plural format key: \"Up to %#@VARIABLE@ at once\"")
  }
  /// Plural format key: "%#@num_servers@ in %#@num_countries@"
  public static func welcomeScreenFeatureServersCountries(_ p1: Int, _ p2: Int) -> String {
    return Localizable.tr("Localizable", "welcome_screen_feature_servers_countries", p1, p2, fallback: "Plural format key: \"%#@num_servers@ in %#@num_countries@\"")
  }
  /// Welcome to Proton screen shown during onboarding. Banner subtitle label.
  public static var welcomeToProtonBannerSubtitle: String { return Localizable.tr("Localizable", "welcome_to_proton_banner_subtitle", fallback: "Your VPN activity is protected by Swiss privacy laws. We’ll never track you online or share your information with third parties.") }
  /// Welcome to Proton screen shown during onboarding. Banner title label.
  public static var welcomeToProtonBannerTitle: String { return Localizable.tr("Localizable", "welcome_to_proton_banner_title", fallback: "Certified no-logs VPN") }
  /// Welcome to Proton screen shown during onboarding. Subtitle label.
  public static var welcomeToProtonSubtitle: String { return Localizable.tr("Localizable", "welcome_to_proton_subtitle", fallback: "Browse privately, access blocked content, and enjoy digital freedom.") }
  /// Welcome to Proton screen shown during onboarding. Title label.
  public static var welcomeToProtonTitle: String { return Localizable.tr("Localizable", "welcome_to_proton_title", fallback: "Welcome to Proton VPN") }
  /// The name of one of the features in the Welcome screen that the user sees after upgrading
  public static var welcomeUpgradeAdvancedFeatures: String { return Localizable.tr("Localizable", "welcome_upgrade_advanced_features", fallback: "Advanced security features") }
  /// The subtitle of the Welcome screen when user upgrades, but we couldn't determine to what plan
  public static var welcomeUpgradeSubtitleFallback: String { return Localizable.tr("Localizable", "welcome_upgrade_subtitle_fallback", fallback: "You've upgraded your subscription. Enjoy advanced privacy features and next-level performance.") }
  /// The subtitle of the Welcome screen when user upgrades to VPN Plus
  public static var welcomeUpgradeSubtitlePlus: String { return Localizable.tr("Localizable", "welcome_upgrade_subtitle_plus", fallback: "Enjoy extra privacy features, supercharged performance, and next-level VPN customization.") }
  /// The subtitle of the Welcome screen when user upgrades to VPN Unlimited
  public static var welcomeUpgradeSubtitleUnlimited: String { return Localizable.tr("Localizable", "welcome_upgrade_subtitle_Unlimited", fallback: "Congratulations! You unlocked premium security and performance features on all Proton services, plus 500 GB total storage.\n\nEnjoy the best of Proton privacy.") }
  /// The bold portion of the subtitle of the Welcome screen when user upgrades to VPN Unlimited
  public static var welcomeUpgradeSubtitleUnlimitedBold: String { return Localizable.tr("Localizable", "welcome_upgrade_subtitle_Unlimited_bold", fallback: "500 GB") }
  /// The subtitle of the Welcome screen when user upgrades to VPN Unlimited with markdown
  public static var welcomeUpgradeSubtitleUnlimitedMarkdown: String { return Localizable.tr("Localizable", "welcome_upgrade_subtitle_Unlimited_markdown", fallback: "Congratulations! You unlocked premium security and performance features on all Proton services, plus **500 GB** total storage.\n\nEnjoy the best of Proton privacy.") }
  /// The title of the Welcome screen when user upgrades, but we couldn't determine to what plan
  public static var welcomeUpgradeTitleFallback: String { return Localizable.tr("Localizable", "welcome_upgrade_title_fallback", fallback: "Congratulations!") }
  /// The title of the Welcome screen when user upgrades to VPN Plus
  public static var welcomeUpgradeTitlePlus: String { return Localizable.tr("Localizable", "welcome_upgrade_title_plus", fallback: "Welcome to VPN Plus") }
  /// The title of the Welcome screen when user upgrades to VPN Unlimited
  public static var welcomeUpgradeTitleUnlimited: String { return Localizable.tr("Localizable", "welcome_upgrade_title_unlimited", fallback: "Welcome to Proton Unlimited") }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension Localizable {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = localizeStringAndFallbackToEn(key, table, value)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
