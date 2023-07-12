// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum Localizable {
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
  /// Countries tab in bottom menu [Redesign_2023]
  public static var countriesTab: String { return Localizable.tr("Localizable", "_countries_tab", fallback: "Countries") }
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
  /// Secure core: connected to a country via another country. %@ is the country through which we are transiting to get to the final destination. [Redesign_2023]
  public static func secureCoreViaCountry(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_secure_core_via_country", String(describing: p1), fallback: "via %@")
  }
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
  /// Text describing the app version in the footer of the Settings tab. %@ will be replaced by a version number in the form of 5.0.0 (1234567890) [Redesign_2023]
  public static func settingsAppVersion(_ p1: Any) -> String {
    return Localizable.tr("Localizable", "_settings_app_version", String(describing: p1), fallback: "App Version: %@")
  }
  /// Represents the OFF state of the Kill Switch feature. Displayed in the Kill Switch settings cell in the Settings tab, and when drilled into the Kill Switch settings view [Redesign_2023]
  public static var settingsKillswitchOff: String { return Localizable.tr("Localizable", "_settings_killswitch_off", fallback: "Off") }
  /// Represents the ON state of the Kill Switch feature. Displayed in the Kill Switch settings cell in the Settings tab, and when drilled into the Kill Switch settings view [Redesign_2023]
  public static var settingsKillswitchOn: String { return Localizable.tr("Localizable", "_settings_killswitch_on", fallback: "On") }
  /// Represents the OFF state of the NetShield feature. Displayed in the NetShield settings cell in the Settings tab, and when drilled into the NetShield settings view [Redesign_2023]
  public static var settingsNetshieldOff: String { return Localizable.tr("Localizable", "_settings_netshield_off", fallback: "Off") }
  /// Represents the ON state of the NetShield feature. Displayed in the NetShield settings cell in the Settings tab, and when drilled into the NetShield settings view [Redesign_2023]
  public static var settingsNetshieldOn: String { return Localizable.tr("Localizable", "_settings_netshield_on", fallback: "On") }
  /// Body of an alert shown in Protocol Settings, when the user attempts to select a different protocol, while a VPN Connection is active. The alert warns the user that changing the VPN protocol will require the current VPN session to be disconnected. [Redesign 2023]
  public static var settingsProtocolAlertBody: String { return Localizable.tr("Localizable", "_settings_protocol_alert_body", fallback: "Changing protocols will end your current VPN session.") }
  /// Cancel button text for the protocol change reconnection alert in Protocol Settings. The alert warns the user that changing the VPN protocol will require the current VPN session to be disconnected. [Redesign 2023]
  public static var settingsProtocolAlertButtonCancel: String { return Localizable.tr("Localizable", "_settings_protocol_alert_button_cancel", fallback: "Cancel") }
  /// Confirmation button text for the protocol change reconnection alert in Protocol Settings. The alert warns the user that changing the VPN protocol will require the current VPN session to be disconnected. [Redesign 2023]
  public static var settingsProtocolAlertButtonContinue: String { return Localizable.tr("Localizable", "_settings_protocol_alert_button_continue", fallback: "Continue") }
  /// Title of an alert shown in Protocol Settings, when the user attempts to select a different protocol, while a VPN Connection is active. The alert warns the user that changing the VPN protocol will require the current VPN session to be disconnected. [Redesign 2023]
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
  /// Footer at the bottom of the Protocol Settings screen. Formatted with markdown, to embed a hyperlink to https://protonvpn.com/blog/whats-the-best-vpn-protocol/ [Redesign 2023]
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
  /// Home screen: Connection card hint on hover (macOS) [Redesign_2023]
  public static var showConnectionDetailsButtonHint: String { return Localizable.tr("Localizable", "_show_connection_details_button_hint", fallback: "Show connection details") }
  /// Plural format key: "%#@STEP@ %#@STEPS@"
  public static func stepOf(_ p1: Int, _ p2: Int) -> String {
    return Localizable.tr("Localizable", "_step_of", p1, p2, fallback: "Plural format key: \"%#@STEP@ %#@STEPS@\"")
  }
  /// Connection status title when user is connected to a VPN [Redesign_2023]
  public static var connectionStatusProtected: String { return Localizable.tr("Localizable", "connection_status_protected", fallback: "Protected") }
  /// Connection status title when user is initiating connection to a VPN [Redesign_2023]
  public static var connectionStatusProtecting: String { return Localizable.tr("Localizable", "connection_status_protecting", fallback: "Protecting your digital identity") }
  /// Connection status title when user is not connected to a VPN [Redesign_2023]
  public static var connectionStatusUnprotected: String { return Localizable.tr("Localizable", "connection_status_unprotected", fallback: "You are unprotected") }
  /// The hint that appears on mac when user hovers with a mouse over the value of netshield stats - advertisements blocked
  public static var netshieldStatsHintAds: String { return Localizable.tr("Localizable", "netshield_stats_hint_ads", fallback: "Advertisement websites use cookies and trackers to target you.") }
  /// The hint that appears on mac when user hovers with a mouse over the value of netshield stats - data saved
  public static var netshieldStatsHintData: String { return Localizable.tr("Localizable", "netshield_stats_hint_data", fallback: "Estimated size of ads, trackers, and malware that NetShield has blocked.") }
  /// The hint that appears on mac when user hovers with a mouse over the value of netshield stats - trackers stopped
  public static var netshieldStatsHintTrackers: String { return Localizable.tr("Localizable", "netshield_stats_hint_trackers", fallback: "Trackers are third-party websites that collect, store, and sell information about your web activity.") }
  /// Button title when user is on lower tier than the server requires [Redesign_2023]
  public static var upsellGetPlus: String { return Localizable.tr("Localizable", "upsell_get_plus", fallback: "Get Plus") }
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
