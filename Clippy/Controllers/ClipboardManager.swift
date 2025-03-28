import Foundation
import SwiftUI
import Combine
import CryptoKit

class ClipboardManager: ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var justCopied = false
    @Published var pinnedItems: [ClipboardItem] = []
    private weak var timer: Timer?
    private weak var autoDeleteTimer: Timer?
    private var pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private let maxItems = 30
    private var lastUpdateTime = Date()
    private let updateThreshold: TimeInterval = 0.2
    private let maxImageSize: Int = 1024 * 1024 * 5 // 5MB limit for images
    private var isInternalPasteboardChange = false
    private var lastCopiedItemId: UUID?
    private let serialProcessingQueue = DispatchQueue(label: "com.clippy.serialProcessing")
    
    // Enhanced sensitive content patterns
    private var sensitiveContentPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"(?:\d[ -]*?){13,16}"#), // Credit card
        try! NSRegularExpression(pattern: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#), // Email
        try! NSRegularExpression(pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#), // IP address
        try! NSRegularExpression(pattern: #"(?:password|passwd|pwd)[\s:=]+\S+"#, options: .caseInsensitive), // Passwords
        try! NSRegularExpression(pattern: #"[A-Z]{2}\d{2}(?:[ ]\d{4}[ ]\d{4}[ ]\d{4}[ ]\d{4}[ ]\d{4}|[-]\d{4}[-]\d{4}[-]\d{4}[-]\d{4}[-]\d{4}|\d{16})"#), // IBAN
        try! NSRegularExpression(pattern: #"[0-9a-fA-F]{64}"#) // SHA-256 hashes or private keys
    ]
    
    // List of apps to exclude from monitoring - always get fresh values
    private var excludedApps: [String] {
        return UserDefaults.standard.stringArray(forKey: "excludedApps") ?? []
    }
    
    // Encryption key derived from device identifier
    private lazy var encryptionKey: SymmetricKey = {
        let deviceID = UserDefaults.standard.string(forKey: "deviceIdentifier") 
            ?? (uniqueDeviceIdentifier().data(using: .utf8)!.base64EncodedString())
        UserDefaults.standard.set(deviceID, forKey: "deviceIdentifier")
        
        let keyData = SHA256.hash(data: deviceID.data(using: .utf8)!)
        return SymmetricKey(data: keyData)
    }()
    
    init() {
        lastChangeCount = pasteboard.changeCount
        
        // Enable categories by default if the setting doesn't exist yet
        if UserDefaults.standard.object(forKey: "enableCategories") == nil {
            UserDefaults.standard.set(true, forKey: "enableCategories")
        }
        
        // Enable sensitive content detection by default
        if UserDefaults.standard.object(forKey: "detectSensitiveContent") == nil {
            UserDefaults.standard.set(true, forKey: "detectSensitiveContent")
        }
        
        // Enable encryption by default for better privacy
        if UserDefaults.standard.object(forKey: "encryptStorage") == nil {
            UserDefaults.standard.set(true, forKey: "encryptStorage")
        }
        
        loadSavedItems()
        startMonitoring()
        setupAutoDeleteTimer()
        
        // Listen for auto-delete setting changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UpdateAutoDeleteSettings"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setupAutoDeleteTimer()
        }
        
        // Listen for excluded apps changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExcludedAppsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let apps = notification.userInfo?["excludedApps"] as? [String] {
                // The array is already saved to UserDefaults, just log it
                #if DEBUG
                print("Updated excluded apps: \(apps)")
                #endif
            }
        }
    }
    
    deinit {
        stopMonitoring()
        autoDeleteTimer?.invalidate()
        autoDeleteTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        // Skip if we're in the middle of an internal clipboard operation
        if isInternalPasteboardChange {
            return
        }
        
        // Optimize polling by checking time threshold
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) < updateThreshold {
            return
        }
        
        // Only process if change count actually changed
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        
        lastChangeCount = currentCount
        lastUpdateTime = now
        
        // Check if current app is excluded
        if shouldExcludeCurrentApp() {
            return
        }
        
        // Use serial queue to ensure ordered processing
        serialProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let url = self.pasteboard.string(forType: .string),
               let parsedURL = URL(string: url),
               parsedURL.scheme != nil {
                self.addItem(url: parsedURL)
            } else if let string = self.pasteboard.string(forType: .string) {
                self.addItem(string)
            } else if let image = self.pasteboard.data(forType: .tiff) {
                self.addItem(imageData: image)
            }
        }
    }
    
    private func shouldExcludeCurrentApp() -> Bool {
        guard !excludedApps.isEmpty else { return false }
        
        // Get the frontmost app's bundle identifier using multiple methods for reliability
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            let bundleId = frontmostApp.bundleIdentifier ?? ""
            let appName = frontmostApp.localizedName ?? "Unknown"
            
            // For debugging
            #if DEBUG
            print("Current app: \(appName) (\(bundleId))")
            print("Excluded apps: \(excludedApps)")
            #endif
            
            // Check if the app is in our exclusion list
            for excludedId in excludedApps {
                if bundleId == excludedId {
                    #if DEBUG
                    print("Excluding clipboard from: \(appName)")
                    #endif
                    return true
                }
            }
        } else {
            // Try alternate method to detect active app
            let runningApps = NSWorkspace.shared.runningApplications
            let activeApps = runningApps.filter { $0.isActive }
            
            if let activeApp = activeApps.first {
                let bundleId = activeApp.bundleIdentifier ?? ""
                
                if excludedApps.contains(bundleId) {
                    return true
                }
            }
        }
        
        return false
    }
    
    func addItem(_ string: String) {
        guard !string.isEmpty else { return }
        if let firstItem = clipboardItems.first, firstItem.type == .text && firstItem.text == string {
            return
        }
        
        if UserDefaults.standard.bool(forKey: "detectSensitiveContent") && containsSensitiveData(string) {
            if UserDefaults.standard.bool(forKey: "skipSensitiveContent") {
                return
            }
            
            // No longer mask the content with bullet points
            // Store the content directly but mark it as sensitive
            let newItem = ClipboardItem(text: string, isSensitive: true)
            
            DispatchQueue.main.async {
                self.clipboardItems.insert(newItem, at: 0)
                if self.clipboardItems.count > self.maxItems {
                    self.clipboardItems.removeLast()
                }
                self.saveItems()
            }
        } else {
            let newItem = ClipboardItem(text: string)
            
            DispatchQueue.main.async {
                self.clipboardItems.insert(newItem, at: 0)
                if self.clipboardItems.count > self.maxItems {
                    self.clipboardItems.removeLast()
                }
                self.saveItems()
            }
        }
    }
    
    func addItem(imageData rawData: Data) {
        // Skip processing if the image is too large
        guard rawData.count <= maxImageSize else { return }
        
        // Optimize image data before storing
        let optimizedData = optimizeImageData(rawData)
        
        let newItem = ClipboardItem(imageData: optimizedData)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.clipboardItems.insert(newItem, at: 0)
            if self.clipboardItems.count > self.maxItems {
                self.clipboardItems.removeLast()
            }
            self.saveItems()
        }
    }
    
    func addItem(url: URL) {
        let newItem = ClipboardItem(url: url)
        
        DispatchQueue.main.async {
            self.clipboardItems.insert(newItem, at: 0)
            if self.clipboardItems.count > self.maxItems {
                self.clipboardItems.removeLast()
            }
            self.saveItems()
        }
    }
    
    func copyItemToPasteboard(_ item: ClipboardItem) {
        // Set flag to prevent recording our own paste operation
        isInternalPasteboardChange = true
        lastCopiedItemId = item.id
        
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            if let text = item.text {
                // If it's sensitive, decrypt the original text for pasting
                if item.isSensitive, let originalText = item.originalText {
                    if let decryptedText = decrypt(originalText) {
                        pasteboard.setString(decryptedText, forType: .string)
                    } else {
                        pasteboard.setString(text, forType: .string)
                    }
                } else {
                    pasteboard.setString(text, forType: .string)
                }
            }
        case .image:
            if let imageData = item.imageData {
                pasteboard.setData(imageData, forType: .tiff)
            }
        case .url:
            if let urlString = item.text {
                pasteboard.setString(urlString, forType: .string)
            }
        }
        
        // Update last change count to avoid detecting our own change
        lastChangeCount = pasteboard.changeCount
        
        DispatchQueue.main.async { [weak self] in
            self?.justCopied = true
            
            // Move item to top of list if it exists
            if let index = self?.clipboardItems.firstIndex(where: { $0.id == item.id }) {
                // Create a new item with the same content to trigger code detection
                if item.type == .text, let text = item.text {
                    let newItem = ClipboardItem(
                        text: text,
                        originalText: item.originalText,
                        isSensitive: item.isSensitive
                    )
                    self?.clipboardItems.remove(at: index)
                    self?.clipboardItems.insert(newItem, at: 0)
                } else {
                    if let movedItem = self?.clipboardItems.remove(at: index) {
                        self?.clipboardItems.insert(movedItem, at: 0)
                    }
                }
                self?.saveItems()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.justCopied = false
                self?.isInternalPasteboardChange = false
            }
        }
    }
    
    // MARK: - Encryption Methods
    
    private func uniqueDeviceIdentifier() -> String {
        let hostName = ProcessInfo.processInfo.hostName
        let userName = ProcessInfo.processInfo.userName
        let modelIdentifier = getModelIdentifier()
        return "\(hostName)-\(userName)-\(modelIdentifier)"
    }
    
    private func getModelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    private func encrypt(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else {
            return string
        }
        
        do {
            let encryptedData = try ChaChaPoly.seal(data, using: encryptionKey).combined
            return encryptedData.base64EncodedString()
        } catch {
            return string
        }
    }
    
    private func decrypt(_ base64String: String) -> String? {
        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }
        
        do {
            let sealedBox = try ChaChaPoly.SealedBox(combined: data)
            let decryptedData = try ChaChaPoly.open(sealedBox, using: encryptionKey)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    private func saveItems() {
        let encoder = JSONEncoder()
        
        // Create filtered versions for storage with size optimization
        let storableItems: [ClipboardItem] = clipboardItems.compactMap { item in
            // Skip large images for persistent storage
            if item.type == .image && (item.imageData?.count ?? 0) > 500000 {
                return nil
            }
            
            return item
        }
        
        // Use background queue for saving
        DispatchQueue.global(qos: .background).async {
            // Save items with better error handling
            do {
                let encoded = try encoder.encode(storableItems)
                
                // Encrypt the entire storage if privacy setting enabled
                if UserDefaults.standard.bool(forKey: "encryptStorage") {
                    let encryptedData = self.encryptData(encoded)
                    UserDefaults.standard.set(encryptedData, forKey: "savedClipboardItems")
                } else {
                    UserDefaults.standard.set(encoded, forKey: "savedClipboardItems")
                }
            } catch {
                print("Error saving clipboard items: \(error)")
            }
        }
    }
    
    private func loadSavedItems() {
        if let savedData = UserDefaults.standard.data(forKey: "savedClipboardItems") {
            // Try to decrypt if needed
            let dataToLoad: Data
            if UserDefaults.standard.bool(forKey: "encryptStorage") {
                if let decryptedData = decryptData(savedData) {
                    dataToLoad = decryptedData
                } else {
                    dataToLoad = savedData // Fall back to using as-is
                }
            } else {
                dataToLoad = savedData
            }
            
            do {
                let loadedItems = try JSONDecoder().decode([ClipboardItem].self, from: dataToLoad)
                clipboardItems = loadedItems
            } catch {
                print("Error loading clipboard items: \(error)")
                // If loading fails, start with empty list
                clipboardItems = []
            }
        }
        
        // Load pinned items with similar approach
        if let savedData = UserDefaults.standard.data(forKey: "pinnedClipboardItems") {
            // Try to decrypt if needed
            let dataToLoad: Data
            if UserDefaults.standard.bool(forKey: "encryptStorage") {
                if let decryptedData = decryptData(savedData) {
                    dataToLoad = decryptedData
                } else {
                    dataToLoad = savedData
                }
            } else {
                dataToLoad = savedData
            }
            
            do {
                let loadedItems = try JSONDecoder().decode([ClipboardItem].self, from: dataToLoad)
                pinnedItems = loadedItems
            } catch {
                print("Error loading pinned items: \(error)")
                pinnedItems = []
            }
        }
        
        // Run cleanup to remove any items that should be expired
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.runAutoCleanup()
        }
    }
    
    private func runAutoCleanup() {
        let autoDeleteDays = UserDefaults.standard.integer(forKey: "autoDeleteDays")
        
        // Default to 7 days if not set
        let daysToKeep = autoDeleteDays > 0 ? autoDeleteDays : 7
        
        // Calculate cutoff date
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysToKeep, to: Date())!
        
        // Special handling for sensitive data, expires after 1 day regardless of setting
        let sensitiveCutoffDate = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Filter out expired items
            self.clipboardItems = self.clipboardItems.filter { item in
                // Keep pinned items regardless of age
                if self.isPinned(item) {
                    return true
                }
                
                // Remove sensitive items after 24 hours
                if item.isSensitive && item.timestamp < sensitiveCutoffDate {
                    return false
                }
                
                // Keep items that are newer than the cutoff date
                return item.timestamp >= cutoffDate
            }
            
            // Save the filtered list
            self.saveItems()
        }
    }
    
    // Encryption helpers for entire datasets
    private func encryptData(_ data: Data) -> Data {
        do {
            let sealedBox = try ChaChaPoly.seal(data, using: encryptionKey)
            return sealedBox.combined
        } catch {
            return data
        }
    }
    
    private func decryptData(_ data: Data) -> Data? {
        do {
            let sealedBox = try ChaChaPoly.SealedBox(combined: data)
            return try ChaChaPoly.open(sealedBox, using: encryptionKey)
        } catch {
            return nil
        }
    }
    
    func clearHistory() {
        clipboardItems.removeAll()
        saveItems()
    }
    
    private func optimizeImageData(_ data: Data) -> Data {
        // If already small enough, return as is
        if data.count <= 100 * 1024 {  // Under 100KB is fine
            return data
        }
        
        // Use a serial background queue for image processing
        let processingQueue = DispatchQueue(label: "com.clippy.imageProcessing", qos: .utility)
        let result = DispatchSemaphore(value: 0)
        var optimizedData = data
        
        processingQueue.async {
            autoreleasepool {
                if let image = NSImage(data: data) {
                    // Calculate target size - preserve aspect ratio but limit dimensions
                    let maxDimension: CGFloat = 800
                    let originalSize = image.size
                    
                    var targetSize = originalSize
                    if originalSize.width > maxDimension || originalSize.height > maxDimension {
                        let aspectRatio = originalSize.width / originalSize.height
                        
                        if aspectRatio > 1 {
                            // Width is larger
                            targetSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
                        } else {
                            // Height is larger or square
                            targetSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
                        }
                    }
                    
                    // Check if we need to resize
                    if targetSize.width < originalSize.width {
                        if let resizedData = image.resizedImageData(to: targetSize, compressionQuality: 0.7) {
                            // Only use the resized version if it's actually smaller
                            if resizedData.count < data.count {
                                optimizedData = resizedData
                            }
                        }
                    } else {
                        // Just compress without resizing if dimensions are already small
                        if let compressedData = image.compressedImageData(compressionQuality: 0.7) {
                            if compressedData.count < data.count {
                                optimizedData = compressedData
                            }
                        }
                    }
                }
            }
            result.signal()
        }
        
        // Wait for processing to complete with timeout
        _ = result.wait(timeout: .now() + 1.0)
        return optimizedData
    }
    
    func togglePinStatus(_ item: ClipboardItem) {
        if let index = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            // Unpin
            pinnedItems.remove(at: index)
        } else {
            // Pin
            pinnedItems.append(item)
            
            // Make sure we don't have too many pinned items
            if pinnedItems.count > 10 {
                pinnedItems.removeFirst()
            }
        }
        
        // Save pinned items
        savePinnedItems()
    }
    
    private func savePinnedItems() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(pinnedItems) {
            UserDefaults.standard.set(encoded, forKey: "pinnedClipboardItems")
        }
    }
    
    private func containsSensitiveData(_ text: String) -> Bool {
        for pattern in sensitiveContentPatterns {
            let range = NSRange(location: 0, length: text.utf16.count)
            if pattern.firstMatch(in: text, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }
    
    // Method no longer needed, but keeping the function signature in case it's called elsewhere
    private func maskSensitiveContent(_ text: String) -> String {
        // Return the original text instead of masking it
        return text
    }
    
    func exportHistory() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(clipboardItems.filter { $0.type != .image }) else {
            return nil
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("clipboard_history_\(Date().timeIntervalSince1970).json")
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to export: \(error)")
            return nil
        }
    }
    
    func importHistory(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let importedItems = try decoder.decode([ClipboardItem].self, from: data)
            
            DispatchQueue.main.async {
                // Add unique items to existing history
                let existingIds = Set(self.clipboardItems.map { $0.id })
                let newItems = importedItems.filter { !existingIds.contains($0.id) }
                
                self.clipboardItems.insert(contentsOf: newItems, at: 0)
                
                // Keep within max items limit
                if self.clipboardItems.count > self.maxItems {
                    self.clipboardItems = Array(self.clipboardItems.prefix(self.maxItems))
                }
                
                self.saveItems()
            }
            
            return true
        } catch {
            print("Failed to import: \(error)")
            return false
        }
    }
    
    func items(for category: ClipboardCategory) -> [ClipboardItem] {
        return clipboardItems.filter { $0.category == category }
    }
    
    // New filter method that combines category and search text filtering
    func filterItems(category: ClipboardCategory?, searchText: String, fromItems: [ClipboardItem]? = nil) -> [ClipboardItem] {
        // Get base items
        let baseItems = fromItems ?? clipboardItems
        
        // Apply category filter if needed
        let categoryFiltered: [ClipboardItem]
        if let category = category {
            categoryFiltered = baseItems.filter { $0.category == category }
        } else {
            categoryFiltered = baseItems
        }
        
        // Apply text search if needed
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { item in
                switch item.type {
                case .text:
                    if let text = item.text {
                        return text.localizedCaseInsensitiveContains(searchText)
                    }
                    return false
                case .url:
                    if let urlString = item.text {
                        return urlString.localizedCaseInsensitiveContains(searchText)
                    }
                    return false
                case .image:
                    // Images can't be searched by text
                    return false
                }
            }
        }
    }
    
    func isPinned(_ item: ClipboardItem) -> Bool {
        return pinnedItems.contains(where: { $0.id == item.id })
    }
    
    func deleteItem(_ item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems.remove(at: index)
            saveItems()
        }
        
        // Also remove from pinned items if it's pinned
        if let pinnedIndex = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            pinnedItems.remove(at: pinnedIndex)
            savePinnedItems()
        }
    }
    
    // Debug method to print items information
    func printItemsInfo() {
        print("--- All Clipboard Items ---")
        for (index, item) in clipboardItems.enumerated() {
            print("Item \(index): Type: \(item.type), Category: \(item.category?.rawValue ?? "none"), Preview: \(item.preview)")
        }
        
        print("--- All Pinned Items ---")
        for (index, item) in pinnedItems.enumerated() {
            print("Item \(index): Type: \(item.type), Category: \(item.category?.rawValue ?? "none"), Preview: \(item.preview)")
        }
    }
    
    private func setupAutoDeleteTimer() {
        // Cancel existing timer
        autoDeleteTimer?.invalidate()
        autoDeleteTimer = nil
        
        // Only set up auto-delete if enabled
        let autoDeleteEnabled = UserDefaults.standard.bool(forKey: "enableAutoDelete")
        guard autoDeleteEnabled else { return }
        
        // Set up a timer to run every 5 minutes to clean up old items
        autoDeleteTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.runAutoCleanup()
        }
        
        // Also run cleanup immediately
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.runAutoCleanup()
        }
    }
}

enum ClipboardItemType: String, Codable {
    case text
    case image
    case url
}

enum ClipboardCategory: String, Codable, CaseIterable {
    case text = "Text"
    case code = "Code"
    case url = "URLs"
    case image = "Images"
    
    var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .url: return "link"
        case .image: return "photo"
        }
    }
    
    var color: Color {
        switch self {
        case .text: return .secondary
        case .code: return .blue
        case .url: return .green
        case .image: return .orange
        }
    }
}

// Structure to hold search configuration
struct ClipboardSearchOptions {
    var query: String = ""
    var categoryFilter: ClipboardCategory? = nil
    var caseSensitive: Bool = false
    var onlyShowCode: Bool = false
    
    var isEmpty: Bool {
        return query.isEmpty && categoryFilter == nil && !onlyShowCode
    }
}

struct ClipboardItem: Identifiable, Codable {
    let id = UUID()
    let timestamp = Date()
    let type: ClipboardItemType
    let text: String?
    let imageData: Data?
    let url: URL?
    let originalText: String?
    var category: ClipboardCategory?
    let isSensitive: Bool
    var sourceApp: String?
    
    init(text: String, originalText: String? = nil, isSensitive: Bool = false) {
        if let url = URL(string: text), url.scheme != nil {
            self.type = .url
            self.text = text
            self.url = url
            self.imageData = nil
            self.originalText = originalText
            self.category = .url
            self.isSensitive = isSensitive
        } else {
            self.type = .text
            self.text = text
            self.url = nil
            self.imageData = nil
            self.originalText = originalText
            self.isSensitive = isSensitive
            
            // Always check for code detection, regardless of categories setting
            let isCode = self.detectedLanguage != nil
            
            // Only use categories if enabled, but still detect code
            if UserDefaults.standard.bool(forKey: "enableCategories") {
                self.category = isCode ? .code : .text
            } else {
                self.category = nil
            }
        }
        
        // Capture the source app
        self.sourceApp = ClipboardItem.getCurrentAppName()
    }
    
    init(imageData: Data) {
        self.type = .image
        self.text = nil
        self.url = nil
        self.imageData = imageData
        self.originalText = nil
        self.isSensitive = false
        self.category = .image
        
        // Capture the source app
        self.sourceApp = ClipboardItem.getCurrentAppName()
    }
    
    init(url: URL) {
        self.type = .url
        self.text = url.absoluteString
        self.url = url
        self.imageData = nil
        self.originalText = nil
        self.isSensitive = false
        self.category = .url
        
        // Capture the source app
        self.sourceApp = ClipboardItem.getCurrentAppName()
    }
    
    // Get the current active application name
    static func getCurrentAppName() -> String? {
        // Get the frontmost app using NSWorkspace
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            return frontmostApp.localizedName
        }
        return nil
    }
    
    var preview: String {
        switch type {
        case .text:
            let maxLength = 60
            if let text = text, text.count > maxLength {
                return String(text.prefix(maxLength)) + "..."
            }
            return text ?? ""
        case .image:
            return "[Image]"
        case .url:
            if let url = url {
                let displayString = url.host ?? url.absoluteString
                return displayString
            }
            return "[URL]"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, type, text, imageData, url, originalText, category, isSensitive, sourceApp
    }
} 