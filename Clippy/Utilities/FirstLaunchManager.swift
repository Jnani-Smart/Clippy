import Foundation

class FirstLaunchManager {
    static let shared = FirstLaunchManager()
    
    private let userDefaults = UserDefaults.standard
    private let firstLaunchKey = "hasLaunchedBefore"
    private let lastVersionKey = "lastLaunchedVersion"
    
    private init() {}
    
    var isFirstLaunch: Bool {
        !userDefaults.bool(forKey: firstLaunchKey)
    }
    
    var isNewVersionLaunch: Bool {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return false
        }
        
        let lastVersion = userDefaults.string(forKey: lastVersionKey) ?? ""
        return lastVersion != currentVersion
    }
    
    func markAsLaunched() {
        userDefaults.set(true, forKey: firstLaunchKey)
        
        if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            userDefaults.set(currentVersion, forKey: lastVersionKey)
        }
    }
    
    func resetFirstLaunchFlag() {
        userDefaults.set(false, forKey: firstLaunchKey)
    }
}