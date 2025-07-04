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
    private let maxImageSize: Int = 1024 * 1024 * 20 // 20MB limit for uncompressed images
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
        ) { _ in
            // Notification received for excluded apps change
            // The array is already saved to UserDefaults by the sender
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
        
        // Check if this might be Handoff content - always process Handoff regardless of internal flags
        let isHandoffContent = isLikelyHandoffContent()
        
        #if DEBUG
        if isHandoffContent {
            print("🔄 Detected ACTUAL Handoff content from another device")
        } else {
            print("📱 Regular clipboard content from current device")
        }
        #endif
        
        // Check if this is from a recent internal paste operation
        // Allow Handoff content to bypass this check
        if isInternalPasteboardChange && !isHandoffContent {
            // Reset the flag after a brief delay to ensure we don't miss subsequent external changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.isInternalPasteboardChange = false
            }
            return
        }
        
        // Check if current app is excluded (but allow Handoff content)
        if shouldExcludeCurrentApp() && !isHandoffContent {
            return
        }
        
        // Use serial queue to ensure ordered processing
        serialProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if we have any clipboard content to process
            let availableTypes = self.pasteboard.types ?? []
            
            // Log Handoff detection for debugging
            #if DEBUG
            if isHandoffContent {
                print("🔄 Detected potential Handoff content with types: \(availableTypes.map { $0.rawValue })")
            } else {
                print("📋 Processing regular clipboard content with types: \(availableTypes.map { $0.rawValue })")
            }
            #endif
            
            // Process different types of clipboard content
            // Note: Don't use else-if here because Handoff might provide multiple types
            
            // First, check for file URLs (common in Handoff)
            var fileProcessed = false
            if availableTypes.contains(NSPasteboard.PasteboardType("public.file-url")) {
                if let fileURLData = self.pasteboard.data(forType: NSPasteboard.PasteboardType("public.file-url")) {
                    #if DEBUG
                    print("📁 Processing file URL data: \(fileURLData.count) bytes")
                    #endif
                    
                    // Try to get the file URL
                    if let fileURL = self.extractFileURL(from: fileURLData) {
                        #if DEBUG
                        print("📁 Extracted file URL: \(fileURL)")
                        #endif
                        
                        // Check if this is an image file
                        let imageExtensions = ["jpg", "jpeg", "png", "gif", "tiff", "tif", "bmp", "svg", "webp", "heic", "heif"]
                        let fileExtension = fileURL.pathExtension.lowercased()
                        
                        if imageExtensions.contains(fileExtension) {
                            #if DEBUG
                            print("📁 File is an image, attempting to load: \(fileURL)")
                            #endif
                            
                            // Try to load the image data from the file
                            do {
                                let imageData = try Data(contentsOf: fileURL)
                                #if DEBUG
                                print("📁 Successfully loaded image data: \(imageData.count) bytes")
                                #endif
                                self.addItem(imageData: imageData, isFromHandoff: isHandoffContent)
                                fileProcessed = true
                            } catch {
                                #if DEBUG
                                print("📁 Failed to load image data: \(error)")
                                #endif
                                // Fall back to adding the URL itself
                                self.addItem(url: fileURL, isFromHandoff: isHandoffContent)
                                fileProcessed = true
                            }
                        } else {
                            #if DEBUG
                            print("📁 File is not an image, adding as URL")
                            #endif
                            self.addItem(url: fileURL, isFromHandoff: isHandoffContent)
                            fileProcessed = true
                        }
                    }
                }
            }
            
            // Also check NSFilenamesPboardType for file paths
            if !fileProcessed && availableTypes.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType")) {
                if let filenames = self.pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
                    #if DEBUG
                    print("📁 Processing filenames: \(filenames)")
                    #endif
                    
                    for filename in filenames {
                        let fileURL = URL(fileURLWithPath: filename)
                        #if DEBUG
                        print("📁 Processing filename: \(filename)")
                        print("📁 File URL: \(fileURL)")
                        #endif
                        
                        // Check if this is an image file
                        let imageExtensions = ["jpg", "jpeg", "png", "gif", "tiff", "tif", "bmp", "svg", "webp", "heic", "heif"]
                        let fileExtension = fileURL.pathExtension.lowercased()
                        
                        if imageExtensions.contains(fileExtension) {
                            // Try to load the image data from the file
                            do {
                                let imageData = try Data(contentsOf: fileURL)
                                #if DEBUG
                                print("📁 Successfully loaded image data from filename: \(imageData.count) bytes")
                                #endif
                                self.addItem(imageData: imageData, isFromHandoff: isHandoffContent)
                            } catch {
                                #if DEBUG
                                print("📁 Failed to load image data from filename: \(error)")
                                #endif
                                // Fall back to adding the URL itself
                                self.addItem(url: fileURL, isFromHandoff: isHandoffContent)
                            }
                        } else {
                            self.addItem(url: fileURL, isFromHandoff: isHandoffContent)
                        }
                        
                        fileProcessed = true
                        break // Process first file only
                    }
                }
            }
            
            // Then, check for direct images (prioritize images for Handoff)
            var imageProcessed = false
            if !fileProcessed && availableTypes.contains(.tiff) {
                if let imageData = self.pasteboard.data(forType: .tiff) {
                    #if DEBUG
                    if isHandoffContent {
                        print("🖼️ Processing Handoff TIFF image data: \(imageData.count) bytes")
                    } else {
                        print("🖼️ Processing regular TIFF image data: \(imageData.count) bytes")
                    }
                    #endif
                    self.addItem(imageData: imageData, isFromHandoff: isHandoffContent)
                    imageProcessed = true
                }
            }
            
            if !imageProcessed && availableTypes.contains(.png) {
                if let imageData = self.pasteboard.data(forType: .png) {
                    #if DEBUG
                    if isHandoffContent {
                        print("🖼️ Processing Handoff PNG image data: \(imageData.count) bytes")
                    } else {
                        print("🖼️ Processing regular PNG image data: \(imageData.count) bytes")
                    }
                    #endif
                    self.addItem(imageData: imageData, isFromHandoff: isHandoffContent)
                    imageProcessed = true
                }
            }
            
            // Check for other image formats that might come from Handoff
            if !imageProcessed {
                let imageTypes: [NSPasteboard.PasteboardType] = [
                    NSPasteboard.PasteboardType("public.png"),      // PNG format (lossless)
                    NSPasteboard.PasteboardType("public.jpeg"),     // JPEG format
                    NSPasteboard.PasteboardType("public.tiff"),     // TIFF format (lossless)
                    NSPasteboard.PasteboardType("public.image"),    // Generic image
                    NSPasteboard.PasteboardType("com.apple.pict"),  // PICT format
                    NSPasteboard.PasteboardType("public.svg-image"), // SVG support
                    NSPasteboard.PasteboardType("public.heic"),     // HEIC format
                    NSPasteboard.PasteboardType("public.heif"),     // HEIF format
                    NSPasteboard.PasteboardType("public.webp"),     // WebP format
                    NSPasteboard.PasteboardType("public.bmp")       // BMP format
                ]
                
                for imageType in imageTypes {
                    if availableTypes.contains(imageType) {
                        if let imageData = self.pasteboard.data(forType: imageType) {
                            #if DEBUG
                            if isHandoffContent {
                                print("🖼️ Processing Handoff image data of type \(imageType.rawValue): \(imageData.count) bytes (preserving original format)")
                            } else {
                                print("🖼️ Processing regular image data of type \(imageType.rawValue): \(imageData.count) bytes (preserving original format)")
                            }
                            #endif
                            
                            // For SVG and other vector formats, we might need special handling
                            if imageType.rawValue == "public.svg-image" {
                                #if DEBUG
                                print("🎨 Processing SVG image: \(imageData.count) bytes")
                                if let svgString = String(data: imageData, encoding: .utf8) {
                                    print("🎨 SVG content preview: \(svgString.prefix(200))...")
                                }
                                #endif
                                
                                // For SVG, preserve the original data to maintain vector quality
                                self.addItem(imageData: imageData, isFromHandoff: isHandoffContent)
                            } else {
                                // For all other image formats, preserve original data without compression
                                self.addItem(imageData: imageData, isFromHandoff: isHandoffContent)
                            }
                            imageProcessed = true
                            break
                        }
                    }
                }
            }
            
            // Process text content if no image was processed or if this is Handoff (which might have both)
            // For Handoff, we want to capture both image and URL if available
            if !imageProcessed || isHandoffContent {
                // If a file was already processed from Handoff, don't process text separately
                if isHandoffContent && fileProcessed {
                    return
                }
                
                var textProcessed = false
                var urlProcessed = false
                
                if availableTypes.contains(.string) {
                    if let string = self.pasteboard.string(forType: .string) {
                        // Check if it's a URL
                        if let parsedURL = URL(string: string), parsedURL.scheme != nil {
                            self.addItem(url: parsedURL, isFromHandoff: isHandoffContent)
                            urlProcessed = true
                        } else {
                            self.addItem(string, isFromHandoff: isHandoffContent)
                        }
                        textProcessed = true
                    }
                }
                
                // Also check for public.url type specifically (common in Handoff)
                if !urlProcessed && availableTypes.contains(NSPasteboard.PasteboardType("public.url")) {
                    if let urlData = self.pasteboard.data(forType: NSPasteboard.PasteboardType("public.url")),
                       let urlString = String(data: urlData, encoding: .utf8),
                       let parsedURL = URL(string: urlString) {
                        #if DEBUG
                        print("🔗 Processing Handoff URL from public.url: \(urlString)")
                        #endif
                        self.addItem(url: parsedURL, isFromHandoff: isHandoffContent)
                        urlProcessed = true
                    }
                }
                
                // Handle RTF if no other text was processed
                if !textProcessed && availableTypes.contains(.rtf) {
                    if let rtfData = self.pasteboard.data(forType: .rtf),
                       let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                        let plainText = attributedString.string
                        if !plainText.isEmpty {
                            self.addItem(plainText, isFromHandoff: isHandoffContent)
                        }
                    }
                }
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
    
    func addItem(_ string: String, isFromHandoff: Bool = false) {
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
            let newItem = ClipboardItem(text: string, isSensitive: true, isFromHandoff: isFromHandoff)
            
            DispatchQueue.main.async {
                self.clipboardItems.insert(newItem, at: 0)
                if self.clipboardItems.count > self.maxItems {
                    self.clipboardItems.removeLast()
                }
                self.saveItems()
                
                #if DEBUG
                let sourceAppName = newItem.sourceApp ?? "Unknown"
                if isFromHandoff {
                    print("✅ Successfully added Handoff text to clipboard history (source: \(sourceAppName), sensitive: true)")
                } else {
                    print("✅ Successfully added text to clipboard history (source: \(sourceAppName), sensitive: true)")
                }
                #endif
            }
        } else {
            let newItem = ClipboardItem(text: string, isFromHandoff: isFromHandoff)
            
            DispatchQueue.main.async {
                self.clipboardItems.insert(newItem, at: 0)
                if self.clipboardItems.count > self.maxItems {
                    self.clipboardItems.removeLast()
                }
                self.saveItems()
                
                #if DEBUG
                let sourceAppName = newItem.sourceApp ?? "Unknown"
                if isFromHandoff {
                    print("✅ Successfully added Handoff text to clipboard history (source: \(sourceAppName))")
                } else {
                    print("✅ Successfully added text to clipboard history (source: \(sourceAppName))")
                }
                #endif
            }
        }
    }
    
    func addItem(imageData rawData: Data, isFromHandoff: Bool = false) {
        // For Handoff images, be more lenient with size limits
        let sizeLimit = isFromHandoff ? maxImageSize * 2 : maxImageSize
        guard rawData.count <= sizeLimit else {
            #if DEBUG
            print("❌ Skipping image: too large (\(rawData.count) bytes, limit: \(sizeLimit))")
            #endif
            return
        }
        
        // Validate that we can actually create an NSImage from this data
        guard NSImage(data: rawData) != nil else {
            #if DEBUG
            print("❌ Skipping image: invalid image data (\(rawData.count) bytes)")
            #endif
            return
        }
        
        #if DEBUG
        if isFromHandoff {
            print("🔄 Adding Handoff image: \(rawData.count) bytes (uncompressed)")
        } else {
            print("🔄 Adding regular image: \(rawData.count) bytes (uncompressed)")
        }
        #endif
        
        // Check user preference for image compression
        let shouldCompress = UserDefaults.standard.bool(forKey: "compressImages")
        
        var optimizedData: Data
        if shouldCompress {
            #if DEBUG
            print("🔧 Compressing image as per user preference")
            #endif
            // Apply compression based on user preference
            if isFromHandoff {
                optimizedData = optimizeImageData(rawData, isFromHandoff: true)
            } else {
                optimizedData = optimizeImageData(rawData)
            }
            
            // Validate the optimized data
            if optimizedData.isEmpty || NSImage(data: optimizedData) == nil {
                #if DEBUG
                print("❌ Image optimization failed, using original data")
                #endif
                // Fall back to original data if optimization failed
                optimizedData = rawData
            }
        } else {
            #if DEBUG
            print("✅ Preserving original image data without compression (user preference)")
            #endif
            // Preserve original image data without compression
            optimizedData = rawData
        }
        
        let newItem = ClipboardItem(imageData: optimizedData, isFromHandoff: isFromHandoff)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Check if we already have this exact image (to avoid duplicates)
            // Use improved duplicate detection for images, especially uncompressed ones
            let isDuplicate = self.clipboardItems.contains { existingItem in
                guard existingItem.type == .image,
                      let existingData = existingItem.imageData else { return false }
                
                // For uncompressed images, be more precise in duplicate detection
                let shouldCompress = UserDefaults.standard.bool(forKey: "compressImages")
                
                if shouldCompress {
                    // For compressed images, use size-based comparison (within 10%)
                    let sizeDifference = abs(existingData.count - optimizedData.count)
                    let tolerance = max(existingData.count, optimizedData.count) / 10
                    return sizeDifference < tolerance && existingItem.timestamp.timeIntervalSinceNow > -5
                } else {
                    // For uncompressed images, use exact size comparison for better accuracy
                    let sizeDifference = abs(existingData.count - optimizedData.count)
                    let tolerance = max(existingData.count, optimizedData.count) / 100 // 1% tolerance for uncompressed
                    return sizeDifference < tolerance && existingItem.timestamp.timeIntervalSinceNow > -10 // Longer window for uncompressed
                }
            }
            
            if !isDuplicate {
                self.clipboardItems.insert(newItem, at: 0)
                if self.clipboardItems.count > self.maxItems {
                    self.clipboardItems.removeLast()
                }
                self.saveItems()
                
                #if DEBUG
                let sourceAppName = newItem.sourceApp ?? "Unknown"
                if isFromHandoff {
                    print("✅ Successfully added Handoff image to clipboard history (source: \(sourceAppName), size: \(optimizedData.count) bytes)")
                } else {
                    print("✅ Successfully added image to clipboard history (source: \(sourceAppName), size: \(optimizedData.count) bytes)")
                }
                print("📊 Total clipboard items: \(self.clipboardItems.count)")
                #endif
            } else {
                #if DEBUG
                print("⏭️ Skipping duplicate image (within 5 seconds and similar size)")
                #endif
            }
        }
    }
    
    func addItem(url: URL, isFromHandoff: Bool = false) {
        let newItem = ClipboardItem(url: url, isFromHandoff: isFromHandoff)
        
        DispatchQueue.main.async {
            self.clipboardItems.insert(newItem, at: 0)
            if self.clipboardItems.count > self.maxItems {
                self.clipboardItems.removeLast()
            }
            self.saveItems()
            
            #if DEBUG
            let sourceAppName = newItem.sourceApp ?? "Unknown"
            if isFromHandoff {
                print("✅ Successfully added Handoff URL to clipboard history (source: \(sourceAppName)): \(url.absoluteString)")
            } else {
                print("✅ Successfully added URL to clipboard history (source: \(sourceAppName)): \(url.absoluteString)")
            }
            #endif
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
                        isSensitive: item.isSensitive,
                        isFromHandoff: item.isFromHandoff
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
            
            // Reset flags after a brief delay to allow for external clipboard changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.justCopied = false
                self?.isInternalPasteboardChange = false
                self?.lastCopiedItemId = nil
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
    
    private func optimizeImageData(_ data: Data, isFromHandoff: Bool = false) -> Data {
        // For Handoff images, be more lenient with size thresholds
        let sizeThreshold = isFromHandoff ? 200 * 1024 : 100 * 1024 // 200KB for Handoff vs 100KB for others
        
        // If already small enough, return as is
        if data.count <= sizeThreshold {
            #if DEBUG
            print("🔧 Image already small enough (\(data.count) bytes <= \(sizeThreshold)), returning as-is")
            #endif
            return data
        }
        
        #if DEBUG
        print("🔧 Optimizing image: \(data.count) bytes (Handoff: \(isFromHandoff))")
        #endif
        
        // Validate input data
        guard let image = NSImage(data: data) else {
            #if DEBUG
            print("❌ Cannot create NSImage from data")
            // If it's potentially SVG data, let's check
            if let svgString = String(data: data, encoding: .utf8), svgString.contains("<svg") {
                print("🎨 Data appears to be SVG content, returning as-is for now")
            }
            print("❌ Returning original data")
            #endif
            return data
        }
        
        // Use a serial background queue for image processing
        let processingQueue = DispatchQueue(label: "com.clippy.imageProcessing", qos: .utility)
        let result = DispatchSemaphore(value: 0)
        var optimizedData = data
        
        processingQueue.async {
            autoreleasepool {
                // Calculate target size - preserve aspect ratio but limit dimensions
                // For Handoff images, use higher quality settings
                let maxDimension: CGFloat = isFromHandoff ? 1200 : 800
                let compressionQuality: Double = isFromHandoff ? 0.8 : 0.7
                let originalSize = image.size
                
                #if DEBUG
                print("🔧 Original image size: \(originalSize.width) x \(originalSize.height)")
                #endif
                
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
                    
                    #if DEBUG
                    print("🔧 Target size: \(targetSize.width) x \(targetSize.height)")
                    #endif
                }
                
                // Check if we need to resize
                if targetSize.width < originalSize.width {
                    if let resizedData = image.resizedImageData(to: targetSize, compressionQuality: compressionQuality) {
                        // Only use the resized version if it's actually smaller and valid
                        if resizedData.count < data.count && !resizedData.isEmpty {
                            optimizedData = resizedData
                            #if DEBUG
                            print("🔧 Resized image: \(data.count) -> \(resizedData.count) bytes")
                            #endif
                        } else {
                            #if DEBUG
                            print("🔧 Resizing didn't improve size or failed, keeping original")
                            #endif
                        }
                    } else {
                        #if DEBUG
                        print("❌ Failed to resize image")
                        #endif
                    }
                } else {
                    // Just compress without resizing if dimensions are already small
                    if let compressedData = image.compressedImageData(compressionQuality: compressionQuality) {
                        if compressedData.count < data.count && !compressedData.isEmpty {
                            optimizedData = compressedData
                            #if DEBUG
                            print("🔧 Compressed image: \(data.count) -> \(compressedData.count) bytes")
                            #endif
                        } else {
                            #if DEBUG
                            print("🔧 Compression didn't improve size or failed, keeping original")
                            #endif
                        }
                    } else {
                        #if DEBUG
                        print("❌ Failed to compress image")
                        #endif
                    }
                }
            }
            result.signal()
        }
        
        // Wait for processing to complete with timeout
        let waitResult = result.wait(timeout: .now() + 3.0) // Increased timeout
        if waitResult == .timedOut {
            #if DEBUG
            print("⏰ Image processing timed out, returning original data")
            #endif
            return data
        }
        
        #if DEBUG
        print("✅ Image optimization complete: \(data.count) -> \(optimizedData.count) bytes")
        #endif
        
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
            let handoffStatus = item.isFromHandoff ? " [HANDOFF]" : ""
            let imageSize = item.type == .image ? " (\(item.imageData?.count ?? 0) bytes)" : ""
            print("Item \(index): Type: \(item.type), Category: \(item.category?.rawValue ?? "none"), Preview: \(item.preview)\(imageSize)\(handoffStatus)")
        }
        
        print("--- All Pinned Items ---")
        for (index, item) in pinnedItems.enumerated() {
            let handoffStatus = item.isFromHandoff ? " [HANDOFF]" : ""
            let imageSize = item.type == .image ? " (\(item.imageData?.count ?? 0) bytes)" : ""
            print("Item \(index): Type: \(item.type), Category: \(item.category?.rawValue ?? "none"), Preview: \(item.preview)\(imageSize)\(handoffStatus)")
        }
        
        // Additional debugging for image items
        let imageItems = clipboardItems.filter { $0.type == .image }
        print("--- Image Items Summary ---")
        print("Total image items: \(imageItems.count)")
        for (index, item) in imageItems.enumerated() {
            let handoffStatus = item.isFromHandoff ? " [HANDOFF]" : " [REGULAR]"
            let hasValidData = item.imageData != nil && !item.imageData!.isEmpty
            let canCreateImage = item.imageData != nil ? (NSImage(data: item.imageData!) != nil) : false
            print("Image \(index): \(item.imageData?.count ?? 0) bytes, Valid: \(hasValidData), Readable: \(canCreateImage)\(handoffStatus)")
        }
    }
    
    // MARK: - Debug Methods
    
    func debugCurrentState() {
        print("🔍 === CLIPBOARD MANAGER DEBUG ===")
        print("📊 Current pasteboard change count: \(pasteboard.changeCount)")
        print("📊 Last recorded change count: \(lastChangeCount)")
        print("📊 Internal pasteboard change flag: \(isInternalPasteboardChange)")
        print("📊 Total clipboard items: \(clipboardItems.count)")
        print("📊 Available pasteboard types: \(pasteboard.types?.map { $0.rawValue } ?? [])")
        
        if let currentString = pasteboard.string(forType: .string) {
            print("📊 Current clipboard string: \(currentString.prefix(50))...")
        }
        
        if let currentImageData = pasteboard.data(forType: .tiff) {
            print("📊 Current clipboard TIFF image: \(currentImageData.count) bytes")
        }
        
        if let currentImageData = pasteboard.data(forType: .png) {
            print("📊 Current clipboard PNG image: \(currentImageData.count) bytes")
        }
        
        printItemsInfo()
        print("🔍 === END DEBUG ===")
    }
    
    func debugHandoffDetection() {
        print("🔍 === HANDOFF DETECTION DEBUG ===")
        let isHandoff = isLikelyHandoffContent()
        print("📊 Is likely Handoff content: \(isHandoff)")
        print("🔍 === END HANDOFF DEBUG ===")
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
    
    // MARK: - Handoff Support
    
    private func isLikelyHandoffContent() -> Bool {
        // Check if the clipboard change might be from Handoff
        // Handoff typically has specific pasteboard types and properties
        let availableTypes = pasteboard.types ?? []
        
        // Log available types for debugging
        #if DEBUG
        print("Available pasteboard types: \(availableTypes.map { $0.rawValue })")
        #endif
        
        // Only check for very specific Handoff indicators that are unique to cross-device clipboard
        let specificHandoffIndicators = [
            "com.apple.is-remote-clipboard", // Explicit Handoff marker
            "com.apple.pasteboard.promised-file-url",
            "com.apple.pasteboard.promised-file-content-type",
            "com.apple.handoff", // Direct handoff type
            "com.apple.continuity" // Continuity feature type
        ]
        
        // Check for explicit Handoff indicators first
        for indicator in specificHandoffIndicators {
            if availableTypes.contains(NSPasteboard.PasteboardType(indicator)) {
                #if DEBUG
                print("Found specific Handoff indicator: \(indicator)")
                #endif
                return true
            }
        }
        
        // Check for Apple's internal Handoff types - but be more specific
        let handoffInternalTypes = availableTypes.filter { type in
            let rawValue = type.rawValue.lowercased()
            return rawValue.contains("handoff") || 
                   rawValue.contains("continuity") ||
                   rawValue.contains("remote-clipboard") ||
                   (rawValue.contains("com.apple") && rawValue.contains("promise"))
        }
        
        if !handoffInternalTypes.isEmpty {
            #if DEBUG
            print("Found Apple Handoff-specific types: \(handoffInternalTypes.map { $0.rawValue })")
            #endif
            return true
        }
        
        // Remove the broad detection that was catching everything
        // Only return true for explicit Handoff indicators
        return false
    }
    
    private func extractFileURL(from data: Data) -> URL? {
        // Try to decode as URL string
        if let urlString = String(data: data, encoding: .utf8) {
            if let url = URL(string: urlString) {
                return url
            }
        }
        return nil
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
    let isFromHandoff: Bool
    
    init(text: String, originalText: String? = nil, isSensitive: Bool = false, isFromHandoff: Bool = false) {
        if let url = URL(string: text), url.scheme != nil {
            self.type = .url
            self.text = text
            self.url = url
            self.imageData = nil
            self.originalText = originalText
            self.category = .url
            self.isSensitive = isSensitive
            self.isFromHandoff = isFromHandoff
        } else {
            self.type = .text
            self.text = text
            self.url = nil
            self.imageData = nil
            self.originalText = originalText
            self.isSensitive = isSensitive
            self.isFromHandoff = isFromHandoff
            
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
        self.sourceApp = ClipboardItem.getCurrentAppName(isFromHandoff: isFromHandoff)
    }
    
    init(imageData: Data, isFromHandoff: Bool = false) {
        self.type = .image
        self.text = nil
        self.url = nil
        self.imageData = imageData
        self.originalText = nil
        self.isSensitive = false
        self.category = .image
        self.isFromHandoff = isFromHandoff
        
        // Capture the source app
        self.sourceApp = ClipboardItem.getCurrentAppName(isFromHandoff: isFromHandoff)
    }
    
    init(url: URL, isFromHandoff: Bool = false) {
        self.type = .url
        self.text = url.absoluteString
        self.url = url
        self.imageData = nil
        self.originalText = nil
        self.isSensitive = false
        self.category = .url
        self.isFromHandoff = isFromHandoff
        
        // Capture the source app
        self.sourceApp = ClipboardItem.getCurrentAppName(isFromHandoff: isFromHandoff)
    }
    
    // Get the current active application name
    static func getCurrentAppName(isFromHandoff: Bool = false) -> String? {
        // If the item is from Handoff, return "Handoff" as the app name
        if isFromHandoff {
            return "Handoff"
        }
        
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
        case id, timestamp, type, text, imageData, url, originalText, category, isSensitive, sourceApp, isFromHandoff
    }
}