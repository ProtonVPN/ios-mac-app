import Foundation

@available(iOS 16.0, *)
extension Bundle {
    public static var atlasSecret: String? {
        #if RELEASE
        return nil
        #else
        let key = "ATLAS_SECRET"
        return ProcessInfo.processInfo.firstArgumentValue(forKey: key) ?? Bundle.main.infoDictionary?[key] as? String
        #endif
    }

    public static var dynamicDomain: String? {
        #if RELEASE
        return nil
        #else
        let key = "DYNAMIC_DOMAIN"
        let value = ProcessInfo.processInfo.firstArgumentValue(forKey: key) ?? Bundle.main.infoDictionary?[key] as? String
        return value.map { domain in
            // If dynamic domain looks like a real URL like https://proton.black/api, then leave it alone.
            // Otherwise, wrap it up in an https/api blanket.
            if let url = URL(string: domain), url.scheme != nil && url.host() != nil {
                return url.absoluteString
            }
            return "https://\(domain)/api"
        }
        #endif
    }

    public static var isTestflight: Bool {
        /*
            Checking for sandbox appstore receipt to determine if the app is beta version
            installed through Testflight is used by:
            * Microsoft's AppCenter:
             https://github.com/microsoft/appcenter-sdk-apple/blob/928227a72dc813070dc05efae04e19fe86558030/AppCenter/AppCenter/Internals/Util/MSACUtility%2BEnvironment.m#L28
            * Sentry:
                https://github.com/getsentry/sentry-cocoa/blob/7185a59493cda3aafcbe3b87652ea0256db2ad59/Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_System.m#L435

            We explore the same idea here.
        */
        
        return Bundle.main.appStoreReceiptURL?.path().contains("sandboxReceipt") == true
    }
}
