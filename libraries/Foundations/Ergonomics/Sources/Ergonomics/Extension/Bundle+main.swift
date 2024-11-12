import Foundation

extension Bundle {
    public static var atlasSecret: String? {
        #if DEBUG
        let key = "ATLAS_SECRET"
        return ProcessInfo.processInfo.firstArgumentValue(forKey: key) ?? Bundle.main.infoDictionary?[key] as? String
        #else
        return nil
        #endif
    }

    public static var dynamicDomain: String? {
        #if DEBUG
        let key = "DYNAMIC_DOMAIN"
        let value = ProcessInfo.processInfo.firstArgumentValue(forKey: key) ?? Bundle.main.infoDictionary?[key] as? String
        return value.map { domain in
            // If dynamic domain looks like a real URL like https://proton.black/api, then leave it alone.
            // Otherwise, wrap it up in an https/api blanket.
            if let url = URL(string: domain), url.scheme != nil {
                return url.absoluteString
            }
            return "https://\(domain)/api"
        }
        #else
        return nil
        #endif
    }
}
