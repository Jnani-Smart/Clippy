import Foundation
import AppKit
import Combine

// MARK: - Auto Update Models
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let publishedAt: String
    let assets: [GitHubAsset]
    let htmlUrl: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body
        case publishedAt = "published_at"
        case assets
        case htmlUrl = "html_url"
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int
    let contentType: String
    
    enum CodingKeys: String, CodingKey {
        case name, size
        case browserDownloadUrl = "browser_download_url"
        case contentType = "content_type"
    }
}

enum UpdateError: LocalizedError {
    case noUpdatesAvailable
    case networkError(Error)
    case downloadError(Error)
    case installationError(Error)
    case invalidResponse
    case noCompatibleAsset
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noUpdatesAvailable:
            return "No updates available"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .downloadError(let error):
            return "Download error: \(error.localizedDescription)"
        case .installationError(let error):
            return "Installation error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .noCompatibleAsset:
            return "No compatible download found"
        case .permissionDenied:
            return "Permission denied for installation"
        }
    }
}

enum UpdateState: Equatable {
    case idle
    case checking
    case updateAvailable(GitHubRelease)
    case downloading(progress: Double)
    case downloadCompleted(url: URL)
    case error(UpdateError)
    
    static func == (lhs: UpdateState, rhs: UpdateState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking):
            return true
        case (.updateAvailable(let lhsRelease), .updateAvailable(let rhsRelease)):
            return lhsRelease.tagName == rhsRelease.tagName
        case (.downloading(let lhsProgress), .downloading(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.downloadCompleted(let lhsURL), .downloadCompleted(let rhsURL)):
            return lhsURL == rhsURL
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Auto Updater Service
@MainActor
class AutoUpdater: ObservableObject {
    static let shared = AutoUpdater()
    
    @Published var updateState: UpdateState = .idle
    @Published var isAutoCheckEnabled = true
    @Published var lastCheckDate: Date?
    
    private let githubOwner = "Jnani-Smart"
    private let githubRepo = "Clippy"
    private let checkInterval: TimeInterval = 3600 // 1 hour
    
    private var checkTimer: Timer?
    private var downloadTask: URLSessionDownloadTask?
    
    private init() {
        setupAutoCheck()
    }
    
    deinit {
        checkTimer?.invalidate()
        downloadTask?.cancel()
    }
    
    // MARK: - Public Interface
    
    func checkForUpdates(silent: Bool = false) async {
        guard updateState != .checking else { return }
        
        if !silent {
            updateState = .checking
        }
        
        do {
            let latestRelease = try await fetchLatestRelease()
            let currentVersion = getCurrentVersion()
            
            if isNewerVersion(latestRelease.tagName, than: currentVersion) {
                updateState = .updateAvailable(latestRelease)
                
                if !silent {
                    await showUpdateNotification(release: latestRelease)
                }
            } else {
                updateState = .idle
                if !silent {
                    await showNoUpdatesAlert()
                }
            }
            
            lastCheckDate = Date()
            
        } catch {
            updateState = .error(.networkError(error))
            if !silent {
                await showErrorAlert(error: error)
            }
        }
    }
    
    func downloadUpdate(release: GitHubRelease) async {
        guard let asset = findCompatibleAsset(in: release.assets) else {
            updateState = .error(.noCompatibleAsset)
            return
        }
        
        do {
            updateState = .downloading(progress: 0.0)
            let downloadedURL = try await downloadAsset(asset)
            
            updateState = .downloadCompleted(url: downloadedURL)
            await showDownloadCompleteAlert(downloadURL: downloadedURL, release: release)
            
        } catch {
            updateState = .error(.downloadError(error))
            await showErrorAlert(error: error)
        }
    }
    

    
    func enableAutoCheck(_ enabled: Bool) {
        isAutoCheckEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "AutoUpdateEnabled")
        
        if enabled {
            setupAutoCheck()
        } else {
            checkTimer?.invalidate()
            checkTimer = nil
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupAutoCheck() {
        guard isAutoCheckEnabled else { return }
        
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForUpdates(silent: false)
            }
        }
        
        // Check immediately on startup if it's been more than 24 hours
        if let lastCheck = lastCheckDate,
           Date().timeIntervalSince(lastCheck) > 86400 {
            Task {
                await checkForUpdates(silent: false)
            }
        } else if lastCheckDate == nil {
            // First run - check after a short delay
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                await checkForUpdates(silent: false)
            }
        }
    }
    
    private func fetchLatestRelease() async throws -> GitHubRelease {
        let urlString = "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw UpdateError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Clippy-AutoUpdater/1.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.invalidResponse
        }
        
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        return release
    }
    
    private func getCurrentVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private func isNewerVersion(_ newVersion: String, than currentVersion: String) -> Bool {
        // Remove 'v' prefix if present
        let cleanNew = newVersion.hasPrefix("v") ? String(newVersion.dropFirst()) : newVersion
        let cleanCurrent = currentVersion.hasPrefix("v") ? String(currentVersion.dropFirst()) : currentVersion
        
        return cleanNew.compare(cleanCurrent, options: .numeric) == .orderedDescending
    }
    
    private func findCompatibleAsset(in assets: [GitHubAsset]) -> GitHubAsset? {
        // Look for macOS app bundle (.app.zip, .dmg, etc.)
        let compatibleExtensions = [".app.zip", ".dmg", ".zip"]
        
        for asset in assets {
            for ext in compatibleExtensions {
                if asset.name.lowercased().contains("mac") && asset.name.lowercased().hasSuffix(ext) {
                    return asset
                }
            }
        }
        
        // Fallback: look for any .dmg or .zip file
        return assets.first { asset in
            asset.name.lowercased().hasSuffix(".dmg") || 
            asset.name.lowercased().hasSuffix(".zip")
        }
    }
    
    private func downloadAsset(_ asset: GitHubAsset) async throws -> URL {
        guard let url = URL(string: asset.browserDownloadUrl) else {
            throw UpdateError.invalidResponse
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] localURL, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let localURL = localURL else {
                        continuation.resume(throwing: UpdateError.downloadError(NSError(domain: "DownloadError", code: -1)))
                        return
                    }
                    
                    // Move to a permanent location
                    let documentsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                    let destinationURL = documentsPath.appendingPathComponent(asset.name)
                    
                    do {
                        // Remove existing file if it exists
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }
                        
                        try FileManager.default.moveItem(at: localURL, to: destinationURL)
                        continuation.resume(returning: destinationURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            downloadTask?.resume()
        }
    }
    

    
    // MARK: - UI Alerts
    
    private func showUpdateNotification(release: GitHubRelease) async {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "Clippy \(release.tagName) is now available. Would you like to download it?"
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "View Release Notes")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            await downloadUpdate(release: release)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(URL(string: release.htmlUrl)!)
        default:
            break
        }
    }
    
    private func showNoUpdatesAlert() async {
        let alert = NSAlert()
        alert.messageText = "You're up to date!"
        alert.informativeText = "Clippy \(getCurrentVersion()) is currently the newest version available."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    private func showDownloadCompleteAlert(downloadURL: URL, release: GitHubRelease) async {
        let alert = NSAlert()
        alert.messageText = "Download Complete"
        alert.informativeText = "Clippy \(release.tagName) has been downloaded to your Downloads folder. You can now install it manually by opening the downloaded file."
        alert.addButton(withTitle: "Show in Finder")
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.selectFile(downloadURL.path, inFileViewerRootedAtPath: downloadURL.deletingLastPathComponent().path)
        }
    }
    
    private func showErrorAlert(error: Error) async {
        let alert = NSAlert()
        alert.messageText = "Update Error"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        alert.runModal()
    }
    

}

// MARK: - UserDefaults Extension
extension UserDefaults {
    var autoUpdateEnabled: Bool {
        get { bool(forKey: "AutoUpdateEnabled") }
        set { set(newValue, forKey: "AutoUpdateEnabled") }
    }
    
    var lastUpdateCheck: Date? {
        get { object(forKey: "LastUpdateCheck") as? Date }
        set { set(newValue, forKey: "LastUpdateCheck") }
    }
}
