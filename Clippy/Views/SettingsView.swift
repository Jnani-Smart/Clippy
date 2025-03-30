import SwiftUI
import ObjectiveC
import Foundation
import CoreGraphics
import Combine

// Import required modules for enhanced functionality
@_exported import UniformTypeIdentifiers
@_exported import AppKit

// First, define a global constant outside the view struct
private let defaultModifierValue: UInt = UInt(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)

// Renamed version of the visual effect view for settings
struct SettingsVisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// Custom close button viewRepresentable
struct CloseButtonRepresentable: NSViewRepresentable {
    var onClose: () -> Void
    
    func makeNSView(context: Context) -> NSButton {
        // Set colors similar to macOS system close button but with glass effect
        let hoverNormalColor = NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white.withAlphaComponent(0.15).cgColor
            : NSColor.black.withAlphaComponent(0.08).cgColor
            
        let hoverActiveColor = NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white.withAlphaComponent(0.3).cgColor
            : NSColor.black.withAlphaComponent(0.15).cgColor
        
        // Create a simple close button instead of using CloseButtonWithHover
        let closeButton = NSButton(frame: NSRect(origin: .zero, size: NSSize(width: 24, height: 24)))
        closeButton.title = "×"  // Set the title directly
        closeButton.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        closeButton.isBordered = false
        closeButton.bezelStyle = .regularSquare // Use a more basic style for better centering
        closeButton.wantsLayer = true
        closeButton.target = context.coordinator
        closeButton.action = #selector(Coordinator.closeButtonClicked(_:))
        closeButton.contentTintColor = .white
        
        // Set up the button appearance
        closeButton.layer?.cornerRadius = 12
        closeButton.layer?.masksToBounds = true
        
        // Add the circular background
        let bgLayer = CALayer()
        bgLayer.cornerRadius = 12
        bgLayer.backgroundColor = hoverNormalColor
        bgLayer.frame = closeButton.bounds
        
        // Clear existing layers and set up the new ones
        closeButton.layer?.sublayers = nil
        closeButton.layer?.addSublayer(bgLayer)
        
        // Perfect centering
        closeButton.alignment = .center
        closeButton.imagePosition = .noImage
        
        // Use attributed string for ultimate control
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping
        
        let attrString = NSAttributedString(
            string: "×",
            attributes: [
                .font: NSFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraphStyle,
                .baselineOffset: 0.5 // Tiny adjustment for visual centering
            ]
        )
        closeButton.attributedTitle = attrString
        
        // Store reference to the button in coordinator
        context.coordinator.button = closeButton
        context.coordinator.normalColor = hoverNormalColor
        context.coordinator.hoverColor = hoverActiveColor
        
        // Set up tracking area directly on the coordinator
        let trackingArea = NSTrackingArea(
            rect: closeButton.bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: context.coordinator, // Use coordinator as owner
            userInfo: nil
        )
        closeButton.addTrackingArea(trackingArea)
        
        return closeButton
    }
    
    func updateNSView(_ nsView: NSButton, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
    }
    
    class Coordinator: NSObject {
        let onClose: () -> Void
        var normalColor: CGColor?
        var hoverColor: CGColor?
        weak var button: NSButton?
        var isCloseInProgress = false
        
        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
            self.normalColor = NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.15).cgColor
                : NSColor.black.withAlphaComponent(0.08).cgColor
                
            self.hoverColor = NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.3).cgColor
                : NSColor.black.withAlphaComponent(0.15).cgColor
        }
        
        @objc func closeButtonClicked(_ sender: NSButton) {
            guard !isCloseInProgress else { return }
            isCloseInProgress = true
            
            // Disable the button to prevent multiple clicks
            sender.isEnabled = false
            
            onClose()
        }
        
        // Mouse event handlers for hover effect
        @objc func mouseEntered(with event: NSEvent) {
            guard let button = self.button,
                  let bgLayer = button.layer?.sublayers?.first else { return }
            bgLayer.backgroundColor = hoverColor
        }
        
        @objc func mouseExited(with event: NSEvent) {
            guard let button = self.button,
                  let bgLayer = button.layer?.sublayers?.first else { return }
            bgLayer.backgroundColor = normalColor
        }
    }
}

// Add CustomButtonStyle definition before its first use
struct CustomButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                // Simplify to a single layer for better performance
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(configuration.isPressed ? 0.08 : 0.05))
            )
            .foregroundColor(color) 
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.2), lineWidth: 0.8)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SettingsView: View {
    @Binding var isPresented: Bool
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 30
    @AppStorage("autoPaste") private var autoPaste = true
    @AppStorage("storeImages") private var storeImages = true
    @AppStorage("detectSensitiveContent") private var detectSensitiveContent = false
    @AppStorage("skipSensitiveContent") private var skipSensitiveContent = false

    // Version info
    private let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }()
    
    @State private var isCheckingForUpdates = false
    @State private var updateStatusMessage = ""
    @State private var releaseURL: URL? = nil
    
    private func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        
        updateStatusMessage = "Checking for updates..."
        
        // Configure your GitHub repository information here
        let owner = "jnanismart" // Replace with your GitHub username
        let repo = "Clippy" // Replace with your repository name
        
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        
        // Create a version-specific URLRequest with appropriate headers
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Clippy-App/\(appVersion)", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { [self] in
                self.isCheckingForUpdates = false
                
                if let error = error {
                    self.updateStatusMessage = "Error checking for updates: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.updateStatusMessage = "Error: Invalid response from server"
                    return
                }
                
                if httpResponse.statusCode == 404 {
                    self.updateStatusMessage = "No releases found on GitHub"
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    self.updateStatusMessage = "Error: Server returned status code \(httpResponse.statusCode)"
                    return
                }
                
                guard let data = data else {
                    self.updateStatusMessage = "Error: No data received"
                    return
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    
                    // Clean up version numbers for comparison
                    let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
                    let currentVersion = self.appVersion
                    
                    // Simple version comparison (this can be enhanced for semantic versioning)
                    if self.isNewerVersion(latestVersion, than: currentVersion) {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                        formatter.timeZone = TimeZone(abbreviation: "UTC")
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        
                        var publishedDate = "recently"
                        if let date = formatter.date(from: release.publishedAt) {
                            let displayFormatter = DateFormatter()
                            displayFormatter.dateStyle = .medium
                            publishedDate = displayFormatter.string(from: date)
                        }
                        
                        self.updateStatusMessage = "New version \(latestVersion) available (released \(publishedDate)).\nVisit GitHub to download."
                        
                        // Create a clickable link to the release
                        self.releaseURL = URL(string: release.htmlUrl)
                    } else {
                        self.updateStatusMessage = "You're using the latest version (\(currentVersion))."
                    }
                } catch {
                    self.updateStatusMessage = "Error parsing update information: \(error.localizedDescription)"
                }
            }
        }
        
        task.resume()
    }
    
    // Helper method to compare version strings
    private func isNewerVersion(_ version1: String, than version2: String) -> Bool {
        let components1 = version1.split(separator: ".").compactMap { Int($0) }
        let components2 = version2.split(separator: ".").compactMap { Int($0) }
        
        // Pad shorter arrays with zeros
        let maxLength = max(components1.count, components2.count)
        let paddedComponents1 = components1 + Array(repeating: 0, count: maxLength - components1.count)
        let paddedComponents2 = components2 + Array(repeating: 0, count: maxLength - components2.count)
        
        // Compare each component
        for (v1, v2) in zip(paddedComponents1, paddedComponents2) {
            if v1 > v2 {
                return true
            } else if v1 < v2 {
                return false
            }
        }
        
        // Versions are identical
        return false
    }
    
    @AppStorage("enableCategories") private var enableCategories = false
    @AppStorage("hideMenuBarIcon") private var hideMenuBarIcon = false
    @AppStorage("hideDockIcon") private var hideDockIcon = false
    @AppStorage("enableAutoDelete") private var enableAutoDelete = false
    @AppStorage("autoDeleteDuration") private var autoDeleteDuration = 86400 // 1 day in seconds
    @State private var selectedTab = 0
    @State private var showSettings = true
    @AppStorage("clipboardShortcutKey") private var shortcutKey: Int = 9 // V key
    @State private var shortcutModifiers: UInt = 0
    @State private var currentKeyCombo: KeyCombo?
    @State private var isQuitInProgress = false
    @State private var isClearHistoryInProgress = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isResettingDefaults = false
    @EnvironmentObject private var clipboardManager: ClipboardManager
    @State private var keyEventMonitor: Any?
    @State private var showConfetti = false
    @State private var showThankYou = false
    @State private var excludedApps: [String] = []
    @AppStorage("encryptStorage") private var encryptStorage = false
    
    // Check if this is the first launch
    private var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Custom title bar with visionOS styling - add padding at top for close button
                ZStack(alignment: .center) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 2)
                }
                .frame(height: 55)
                .padding(.top, 8) // Increased padding for better spacing
                .background(Color.clear)
                .background(DraggableView())
                
                // Tab view with visionOS-inspired styling
                TabView(selection: $selectedTab) {
                    generalSettingsView
                        .tabItem {
                            Label("General", systemImage: "gear")
                        }
                        .tag(0)
                    
                    privacySettingsView
                        .tabItem {
                            Label("Privacy", systemImage: "lock.shield")
                        }
                        .tag(1)
                    
                    categorySettingsView
                        .tabItem {
                            Label("Categories", systemImage: "tag")
                        }
                        .tag(2)
                    
                    shortcutSettingsView
                        .tabItem {
                            Label("Shortcuts", systemImage: "keyboard")
                        }
                        .tag(3)
                    
                    dataManagementView
                        .tabItem {
                            Label("Data Management", systemImage: "folder")
                        }
                        .tag(4)
                    
                    aboutView
                        .tabItem {
                            Label("About", systemImage: "info.circle")
                        }
                        .tag(5)
                }
                .padding(.top, 5)
            }
            .frame(width: 520, height: 460)
            
            // Add close button in the top-left corner
            CloseButtonRepresentable(onClose: {
                isPresented = false
            })
            .frame(width: 24, height: 24)
            .offset(x: 10, y: 10)
        }
        .onAppear {
            // Configure the window to behave as a normal window, not floating
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Settings" || $0.title.isEmpty }) {
                window.level = .normal
                window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
                window.isReleasedWhenClosed = false
                window.center()
                
                // Make the window movable by the background
                window.isMovableByWindowBackground = true
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                
                // Set window title for proper identification
                window.title = "Settings"
            }
            
            // Load excluded apps
            loadExcludedApps()
            
            // Check if this is the first launch of the app
            if isFirstLaunch {
                // Select the About tab
                selectedTab = 5
                
                // Delay to ensure view is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showThankYou = true
                    showConfetti = true
                    
                    // Mark as launched
                    UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                }
            }
            
            // Add a local event monitor to capture the Escape key
            keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // ESC key
                    // Just dismiss the settings instead of quitting
                    isPresented = false
                    return nil // Consume the event
                }
                return event // Pass other events through
            }
            
            // Load from UserDefaults manually
            if let savedModifiers = UserDefaults.standard.object(forKey: "clipboardShortcutModifiers") as? UInt {
                shortcutModifiers = savedModifiers
            } else {
                // Use default value
                shortcutModifiers = UInt(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
                // Save default to UserDefaults
                UserDefaults.standard.set(shortcutModifiers, forKey: "clipboardShortcutModifiers")
            }
            
            // Check if shortcutKey is 0 (uninitialized or reset to nil)
            if shortcutKey == 0 {
                // Reset to default V key (9)
                shortcutKey = 9
                UserDefaults.standard.set(9, forKey: "clipboardShortcutKey")
            }
            
            // Always create a valid KeyCombo
            currentKeyCombo = KeyCombo(key: shortcutKey, modifiers: NSEvent.ModifierFlags(rawValue: shortcutModifiers))
            
            // Ensure the notification is posted to update shortcuts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let combo = currentKeyCombo {
                    NotificationCenter.default.post(
                        name: Notification.Name("UpdateShortcuts"),
                        object: nil,
                        userInfo: ["keyCombo": combo]
                    )
                }
            }
        }
        .onDisappear {
            // Remove the key event monitor when the view disappears
            if let monitor = keyEventMonitor {
                NSEvent.removeMonitor(monitor)
                keyEventMonitor = nil
            }
        }
    }
    
    // General settings with visionOS-inspired styling
    private var generalSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App behavior settings
                VisionOSGroupBox(title: "App Behavior") {
                    VStack(alignment: .leading, spacing: 16) {
                        VisionOSToggle(title: "Start at login", isOn: $startAtLogin)
                        
                        Divider().padding(.vertical, 4)
                        
                        VisionOSToggle(
                            title: "Hide menu bar icon", 
                            description: "When enabled, the menu bar icon will be hidden. You can still access the app using the keyboard shortcut.",
                            isOn: $hideMenuBarIcon
                        )
                        .disabled(hideDockIcon)
                        .onChange(of: hideMenuBarIcon) { _, newValue in
                            NotificationCenter.default.post(
                                name: Notification.Name("UpdateMenuBarIconVisibility"),
                                object: nil,
                                userInfo: ["hideMenuBarIcon": newValue]
                            )
                        }
                        
                        VisionOSToggle(
                            title: "Hide dock icon", 
                            description: "When enabled, the app won't appear in the dock. You can access it via the menu bar icon or keyboard shortcut.",
                            isOn: $hideDockIcon
                        )
                        .onChange(of: hideDockIcon) { _, newValue in
                            if newValue && hideMenuBarIcon {
                                hideMenuBarIcon = false
                                NotificationCenter.default.post(
                                    name: Notification.Name("UpdateMenuBarIconVisibility"),
                                    object: nil,
                                    userInfo: ["hideMenuBarIcon": false]
                                )
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                NotificationCenter.default.post(
                                    name: Notification.Name("UpdateDockIconVisibility"),
                                    object: nil,
                                    userInfo: ["hideDockIcon": newValue]
                                )
                            }
                        }
                    }
                }
                
                // History settings
                VisionOSGroupBox(title: "Clipboard History") {
                    VStack(alignment: .leading, spacing: 16) {
                        VisionOSPicker(
                            title: "Maximum history items",
                            selection: $maxHistoryItems,
                            options: [
                                PickerOption(label: "20", value: 20),
                                PickerOption(label: "30", value: 30),
                                PickerOption(label: "50", value: 50),
                                PickerOption(label: "100", value: 100)
                            ]
                        )
                        
                        VisionOSToggle(title: "Auto-paste after copying", isOn: $autoPaste)
                        
                        VisionOSToggle(title: "Store images in history", isOn: $storeImages)
                    }
                }
                
                // Auto-delete settings
                VisionOSGroupBox(title: "Auto-Delete") {
                    VStack(alignment: .leading, spacing: 16) {
                        VisionOSToggle(
                            title: "Auto-delete old clipboard items",
                            description: "Automatically delete clipboard items after the specified time period.",
                            isOn: $enableAutoDelete
                        )
                        
                        if enableAutoDelete {
                            VisionOSPicker(
                                title: "Delete after",
                                selection: $autoDeleteDuration,
                                options: [
                                    PickerOption(label: "1 hour", value: 3600),
                                    PickerOption(label: "3 hours", value: 10800),
                                    PickerOption(label: "12 hours", value: 43200),
                                    PickerOption(label: "1 day", value: 86400),
                                    PickerOption(label: "3 days", value: 259200),
                                    PickerOption(label: "1 week", value: 604800)
                                ]
                            )
                            .onChange(of: autoDeleteDuration) { _, _ in
                                NotificationCenter.default.post(
                                    name: Notification.Name("UpdateAutoDeleteSettings"),
                                    object: nil
                                )
                            }
                        }
                    }
                }
                
                // Quit button with icon
                VisionOSButton(
                    title: "Quit Clippy",
                    role: .destructive,
                    icon: "power",
                    customColor: Color(red: 0.95, green: 0.26, blue: 0.37), // Ruby red
                    isInProgress: $isQuitInProgress
                ) {
                    guard !isQuitInProgress else { return }
                    isQuitInProgress = true
                    
                    print("Quitting application...")
                    
                    // Use a more direct approach to quit the application
                    DispatchQueue.main.async {
                        // First try standard termination
                        NSApp.terminate(nil)
                        
                        // If we're still running after a short delay, use a more forceful approach
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // If we reach here, termination didn't work, so use exit
                            exit(0)
                        }
                    }
                }
                .padding(.top, 5)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
    // Privacy settings with visionOS-inspired styling
    private var privacySettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Privacy settings
                VisionOSGroupBox(title: "Privacy") {
                    VStack(alignment: .leading, spacing: 16) {
                        VisionOSToggle(
                            title: "Detect sensitive content", 
                            description: "Identifies passwords, credit card numbers, and other personal information.",
                            isOn: $detectSensitiveContent
                        )
                        
                        if detectSensitiveContent {
                            VisionOSToggle(
                                title: "Don't store sensitive content", 
                                description: "Prevents storing detected sensitive information in clipboard history.",
                                isOn: $skipSensitiveContent
                            )
                            .padding(.leading, 16)
                        }
                        
                        VisionOSToggle(
                            title: "Encrypt clipboard storage",
                            description: "All stored clipboard data will be encrypted on your device",
                            isOn: $encryptStorage
                        )
                    }
                }
                
                // App Exclusions
                VisionOSGroupBox(title: "App Exclusions") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Clippy won't monitor clipboard changes from these apps:")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        HStack {
                            Button(action: {
                                addExcludedApp()
                            }) {
                                Label("Add App", systemImage: "plus")
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                excludedApps = []
                                saveExcludedApps()
                            }) {
                                Text("Clear All")
                            }
                            .disabled(excludedApps.isEmpty)
                        }
                        
                        if !excludedApps.isEmpty {
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(excludedApps, id: \.self) { appId in
                                        HStack {
                                            Text(appNameForBundleId(appId))
                                                .font(.system(size: 14))
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                removeExcludedApp(appId)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .frame(height: min(CGFloat(excludedApps.count) * 30, 150))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
    // Category settings with visionOS-inspired styling
    private var categorySettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VisionOSGroupBox(title: "Categories") {
                    VStack(alignment: .leading, spacing: 16) {
                        VisionOSToggle(
                            title: "Enable automatic categories", 
                            description: "When enabled, clipboard items will be automatically categorized based on content.",
                            isOn: $enableCategories
                        )
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("Default Categories")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.top, 8)
                        
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                            VisionOSCategoryRow(name: "Code", icon: "chevron.left.forwardslash.chevron.right", color: .blue)
                            VisionOSCategoryRow(name: "URLs", icon: "link", color: .green)
                            VisionOSCategoryRow(name: "Images", icon: "photo", color: .orange)
                            VisionOSCategoryRow(name: "Text", icon: "doc.text", color: .secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
    // Keyboard shortcut settings with visionOS-inspired styling
    private var shortcutSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VisionOSGroupBox(title: "Keyboard Shortcuts") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 16) {
                            Text("Show clipboard history:")
                                .font(.system(size: 14))
                            
                            Spacer()
                            
                            ShortcutRecorder(keyCombo: $currentKeyCombo)
                                .onChange(of: currentKeyCombo) { _, newValue in
                                    if let combo = newValue {
                                        shortcutKey = combo.key
                                        shortcutModifiers = combo.modifiers.rawValue
                                        UserDefaults.standard.set(shortcutModifiers, forKey: "clipboardShortcutModifiers")
                                        
                                        NotificationCenter.default.post(
                                            name: Notification.Name("UpdateShortcuts"),
                                            object: nil,
                                            userInfo: ["keyCombo": combo]
                                        )
                                    }
                                }
                        }
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("Changes will take effect after restarting the app.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
    // Data management settings with visionOS-inspired styling
    private var dataManagementView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VisionOSGroupBox(title: "Clipboard Data") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Export your clipboard history to a file or import from a previously exported file.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 16)
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                guard !isExporting else { return }
                                isExporting = true
                                exportHistory()
                                // Reset after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isExporting = false
                                }
                            }) {
                                HStack {
                                    if isExporting {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 13))
                                    }
                                    Text("Export History")
                                        .font(.system(size: 14))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(EnhancedButtonStyle(isInProgress: isExporting, customColor: Color(red: 0.35, green: 0.78, blue: 0.42)))
                            .disabled(isExporting)
                            
                            Button(action: {
                                guard !isImporting else { return }
                                isImporting = true
                                importHistory()
                                // Reset after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isImporting = false
                                }
                            }) {
                                HStack {
                                    if isImporting {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                            .font(.system(size: 13))
                                    }
                                    Text("Import History")
                                        .font(.system(size: 14))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(EnhancedButtonStyle(isInProgress: isImporting, customColor: Color(red: 0.6, green: 0.45, blue: 0.86)))
                            .disabled(isImporting)
                        }
                    }
                }
                
                // Reset and Data Management section with a more descriptive title and purpose
                VisionOSGroupBox(title: "System Maintenance") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reset all settings to their default values or clear your clipboard history. Use these options to troubleshoot issues or start fresh.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 16)
                        
                        VisionOSButton(
                            title: "Reset to Defaults",
                            role: .destructive,
                            icon: "arrow.counterclockwise",
                            customColor: Color(red: 0.98, green: 0.26, blue: 0.37), // Ruby red
                            isInProgress: $isResettingDefaults,
                            action: resetToDefaults
                        )
                        
                        // Clear history button
                        VisionOSButton(
                            title: "Clear All History",
                            role: .destructive, 
                            icon: "trash",
                            customColor: Color(red: 0.9, green: 0.47, blue: 0.25), // Rust/Swift orange
                            isInProgress: $isClearHistoryInProgress
                        ) {
                            guard !isClearHistoryInProgress else { return }
                            isClearHistoryInProgress = true
                            
                            print("Attempting to clear clipboard history...")
                            
                            // Use the clipboardManager directly instead of going through the app delegate
                            clipboardManager.clearHistory()
                            print("Successfully cleared history")
                            
                            // Post notification that history was cleared
                            NotificationCenter.default.post(
                                name: Notification.Name("HistoryCleared"),
                                object: nil
                            )
                            
                            // Reset the flag after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isClearHistoryInProgress = false
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
    private var aboutView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App info
                VisionOSGroupBox(title: "About Clippy") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                                .resizable()
                                .frame(width: 64, height: 64)
                                .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Clippy")
                                    .font(.system(size: 20, weight: .bold))
                                Text("Version \(appVersion)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 16)
                        }
                        
                        Divider().padding(.vertical, 8)
                        
                        Text("A modern clipboard manager for macOS")
                            .font(.system(size: 14))
                        
                        Text("© 2025 Jnani Smart")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                
                // Update check
                VisionOSGroupBox(title: "Updates") {
                    VStack(alignment: .leading, spacing: 16) {
                        VisionOSButton(
                            title: "Check for Updates",
                            icon: "arrow.triangle.2.circlepath",
                            customColor: Color(red: 0.35, green: 0.68, blue: 0.99), // JavaScript blue
                            isInProgress: $isCheckingForUpdates,
                            action: checkForUpdates
                        )
                        .frame(width: 180)
                        
                        if !updateStatusMessage.isEmpty {
                            Text(updateStatusMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .multilineTextAlignment(.leading)
                        }
                        
                        if releaseURL != nil {
                            Button("Open Download Page") {
                                if let url = releaseURL {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(EnhancedButtonStyle(customColor: Color(red: 0.35, green: 0.68, blue: 0.99)))
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .overlay(
                ZStack {
                    // iMessage-style confetti animation with perfect timing
                    EnhancedConfettiView(isActive: $showConfetti, duration: 3.5, intensity: 120, burstDuration: 0.3)
                    
                    // Enhanced thank you message overlay with improved animations
                    if showThankYou {
                        EnhancedThankYouView(isShowing: $showThankYou)
                    }
                }
            )
            .onAppear {
                // Check if this is the first launch
                if FirstLaunchManager.shared.isFirstLaunch {
                    // Delay to ensure view is fully loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showThankYou = true
                        showConfetti = true
                        
                        // Mark as launched
                        FirstLaunchManager.shared.markAsLaunched()
                    }
                }
            }
        }
    }
    
    // Reset to defaults function with optimizations
    private func resetToDefaults() {
        // Create a batch of keys to reset for better performance
        let keysToReset = [
            "startAtLogin", "maxHistoryItems", "autoPaste", "storeImages",
            "detectSensitiveContent", "skipSensitiveContent", "enableCategories",
            "hideMenuBarIcon", "hideDockIcon", "enableAutoDelete",
            "autoDeleteDuration", "clipboardShortcutKey", "clipboardShortcutModifiers"
        ]
        
        // Batch remove all keys at once
        for key in keysToReset {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Reset first launch flag to trigger animation on next launch
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
        
        // Sync UserDefaults to ensure changes are saved
        UserDefaults.standard.synchronize()
        
        // Post notification to update UI elements that depend on these settings
        NotificationCenter.default.post(
            name: Notification.Name("SettingsReset"),
            object: nil
        )
        
        // Close settings window
        isPresented = false
        
        // Restart the app after a short delay using a more efficient approach
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let bundleURL = Bundle.main.bundleURL
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [bundleURL.path]
            
            do {
                try task.run()
                // Quit the current instance once new instance is launching
                NSApp.terminate(nil)
            } catch {
                print("Failed to restart: \(error.localizedDescription)")
            }
        }
    }
    
    // Export function
    private func exportHistory() {
        guard let fileURL = clipboardManager.exportHistory() else {
            // Show error
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Could not export clipboard history."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Show save dialog
        let savePanel = NSSavePanel()
        if #available(macOS 12.0, *) {
            savePanel.allowedContentTypes = [.json]
        } else {
            savePanel.allowedFileTypes = ["json"]
        }
        savePanel.nameFieldStringValue = "clipboard_history.json"
        savePanel.title = "Save Clipboard History"
        savePanel.message = "Choose where to save your clipboard history."
        
        // Present as sheet on the correct window
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Settings" }) {
            savePanel.beginSheetModal(for: window) { response in
                if response == .OK, let targetURL = savePanel.url {
                    do {
                        try FileManager.default.copyItem(at: fileURL, to: targetURL)
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Export Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.beginSheetModal(for: window, completionHandler: nil)
                    }
                }
            }
        } else {
            // Fallback to non-sheet presentation
            savePanel.begin { response in
                if response == .OK, let targetURL = savePanel.url {
                    do {
                        try FileManager.default.copyItem(at: fileURL, to: targetURL)
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Export Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }
    
    // Import function
    private func importHistory() {
        let openPanel = NSOpenPanel()
        if #available(macOS 12.0, *) {
            openPanel.allowedContentTypes = [.json]
        } else {
            openPanel.allowedFileTypes = ["json"]
        }
        openPanel.title = "Import Clipboard History"
        openPanel.message = "Select a clipboard history file to import."
        openPanel.allowsMultipleSelection = false
        
        // Present as sheet on the correct window
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Settings" }) {
            openPanel.beginSheetModal(for: window) { response in
                if response == .OK, let url = openPanel.url {
                    let success = clipboardManager.importHistory(from: url)
                    
                    if !success {
                        let alert = NSAlert()
                        alert.messageText = "Import Failed"
                        alert.informativeText = "Could not import clipboard history from the selected file."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.beginSheetModal(for: window, completionHandler: nil)
                    }
                }
            }
        } else {
            // Fallback to non-sheet presentation
            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    let success = clipboardManager.importHistory(from: url)
                    
                    if !success {
                        let alert = NSAlert()
                        alert.messageText = "Import Failed"
                        alert.informativeText = "Could not import clipboard history from the selected file."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }
    
    private func addExcludedApp() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["app"]
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.message = "Select an application to exclude from clipboard monitoring"
        openPanel.prompt = "Exclude"
        
        if openPanel.runModal() == .OK, let appUrl = openPanel.url {
            // Try to get the bundle ID using Bundle
            if let bundle = Bundle(url: appUrl) {
                // Make sure we can get a valid bundle ID
                if let bundleId = bundle.bundleIdentifier, !bundleId.isEmpty {
                    if !excludedApps.contains(bundleId) {
                        excludedApps.append(bundleId)
                        saveExcludedApps()
                        
                        // Force notification of change
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ExcludedAppsChanged"),
                            object: nil,
                            userInfo: ["excludedApps": excludedApps]
                        )
                    }
                    return
                }
            }
            
            // Fallback method if Bundle fails
            let runningApps = NSWorkspace.shared.runningApplications
            for app in runningApps {
                if app.bundleURL == appUrl, let bundleId = app.bundleIdentifier, !bundleId.isEmpty {
                    if !excludedApps.contains(bundleId) {
                        excludedApps.append(bundleId)
                        saveExcludedApps()
                        
                        // Force notification of change
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ExcludedAppsChanged"),
                            object: nil,
                            userInfo: ["excludedApps": excludedApps]
                        )
                    }
                    return
                }
            }
            
            // Alert user if we couldn't get the bundle ID
            let alert = NSAlert()
            alert.messageText = "Could not determine bundle identifier"
            alert.informativeText = "The app couldn't be excluded because its bundle identifier could not be determined."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func removeExcludedApp(_ appId: String) {
        if let index = excludedApps.firstIndex(of: appId) {
            excludedApps.remove(at: index)
            saveExcludedApps()
            
            // Force notification of change
            NotificationCenter.default.post(
                name: NSNotification.Name("ExcludedAppsChanged"),
                object: nil,
                userInfo: ["excludedApps": excludedApps]
            )
        }
    }
    
    private func saveExcludedApps() {
        UserDefaults.standard.set(excludedApps, forKey: "excludedApps")
        UserDefaults.standard.synchronize() // Force immediate save
    }
    
    private func loadExcludedApps() {
        excludedApps = UserDefaults.standard.stringArray(forKey: "excludedApps") ?? []
    }
    
    private func appNameForBundleId(_ bundleId: String) -> String {
        // Try to get the app name from the bundle ID
        let workspace = NSWorkspace.shared
        if let appUrl = workspace.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: appUrl),
           let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return appName
        }
        return bundleId
    }
}

// VisionOS-inspired components

// Group Box with visionOS styling
struct VisionOSGroupBox<Content: View>: View {
    let title: String
    let content: Content
    @State private var isHovered = false
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0.04))
                    .animation(.easeOut(duration: 0.2), value: isHovered)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.primary.opacity(isHovered ? 0.15 : 0.1),
                                Color.primary.opacity(isHovered ? 0.08 : 0.06)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.primary.opacity(isHovered ? 0.06 : 0.03),
                radius: isHovered ? 3 : 1,
                x: 0,
                y: isHovered ? 1 : 0
            )
            .onHover { hovering in
                self.isHovered = hovering
            }
            .animation(.easeOut(duration: 0.2), value: isHovered)
        }
    }
}

// Switch Toggle with visionOS styling
struct VisionOSToggle: View {
    let title: String
    var description: String? = nil
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
            }
            
            if let description = description {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

// Picker with visionOS styling
struct PickerOption<T: Hashable>: Identifiable {
    var id = UUID()
    let label: String
    let value: T
}

struct VisionOSPicker<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [PickerOption<T>]
    
    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 14))
                .frame(minWidth: 100, alignment: .leading)
            
            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(PopUpButtonPickerStyle())
            .labelsHidden()
        }
    }
}

// Button with visionOS styling
struct VisionOSButton: View {
    let title: String
    var role: ButtonRole? = nil
    let action: () -> Void
    @Binding var isInProgress: Bool
    var icon: String? = nil
    var customColor: Color? = nil
    
    init(title: String, role: ButtonRole? = nil, icon: String? = nil, customColor: Color? = nil, isInProgress: Binding<Bool>? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.icon = icon
        self.customColor = customColor
        self._isInProgress = isInProgress ?? .constant(false)
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isInProgress {
                    ProgressView()
                        .controlSize(.small)
                } else if let iconName = icon {
                    Image(systemName: iconName)
                        .font(.system(size: 13))
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .opacity(isInProgress ? 0.7 : 1.0)
        }
        .buttonStyle(EnhancedButtonStyle(role: role, isInProgress: isInProgress, customColor: customColor))
        .disabled(isInProgress)
    }
}

// Enhanced button style for better visual appeal
struct EnhancedButtonStyle: ButtonStyle {
    let role: ButtonRole?
    let isInProgress: Bool
    var customColor: Color? = nil
    @State private var isHovered = false
    
    init(role: ButtonRole? = nil, isInProgress: Bool = false, customColor: Color? = nil) {
        self.role = role
        self.isInProgress = isInProgress
        self.customColor = customColor
    }
    
    private var baseColor: Color {
        if let custom = customColor {
            return custom
        }
        
        // Code-inspired vibrant colors
        if role == .destructive {
            return Color(red: 0.98, green: 0.26, blue: 0.37)  // Ruby/Error red
        } else if role == .cancel {
            return Color(red: 0.65, green: 0.65, blue: 0.68)  // Comment gray
        } else {
            return Color(red: 0.35, green: 0.68, blue: 0.99)  // JavaScript blue
        }
    }
    
    private var textColor: Color {
        if role == .destructive || role == .cancel {
            return baseColor
        } else {
            // Darker foreground for better contrast
            return baseColor
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(baseColor.opacity(configuration.isPressed ? 0.12 : (isHovered ? 0.10 : 0.08)))
            )
            .foregroundColor(textColor.opacity(isHovered ? 1.0 : 0.95))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(baseColor.opacity(isHovered ? 0.3 : 0.25), lineWidth: 0.8)
            )
            .shadow(
                color: baseColor.opacity(isHovered ? 0.08 : 0.06),
                radius: isHovered ? 1.2 : 1,
                x: 0,
                y: isHovered ? 1.2 : 1
            )
            .opacity(isInProgress ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// Category row with visionOS styling
struct VisionOSCategoryRow: View {
    let name: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Text(name)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.green)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// DraggableView for making the title bar draggable
struct DraggableView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableNSView()
        view.wantsLayer = true
        
        // Make view background fully transparent
        view.layer?.backgroundColor = .clear
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Nothing to update
    }
    
    class DraggableNSView: NSView {
        var isDragging = false
        var initialLocation = NSPoint.zero
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            setupTrackingArea()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupTrackingArea()
        }
        
        private func setupTrackingArea() {
            let trackingArea = NSTrackingArea(
                rect: .zero,
                options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            self.addTrackingArea(trackingArea)
        }
        
        override func mouseDown(with event: NSEvent) {
            super.mouseDown(with: event)
            guard let window = self.window else { return }
            
            isDragging = true
            initialLocation = event.locationInWindow
        }
        
        override func mouseDragged(with event: NSEvent) {
            super.mouseDragged(with: event)
            guard let window = self.window, isDragging else { return }
            
            let currentLocation = event.locationInWindow
            let newOrigin = NSPoint(
                x: window.frame.origin.x + (currentLocation.x - initialLocation.x),
                y: window.frame.origin.y + (currentLocation.y - initialLocation.y)
            )
            
            window.setFrameOrigin(newOrigin)
        }
        
        override func mouseUp(with event: NSEvent) {
            super.mouseUp(with: event)
            isDragging = false
        }
    }
}

struct PrivacySection: View {
    @AppStorage("detectSensitiveContent") private var detectSensitiveContent = true
    @AppStorage("skipSensitiveContent") private var skipSensitiveContent = false
    
    // Version info
    private let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }()
    
    @State private var isCheckingForUpdates = false
    @State private var updateStatusMessage = ""
    
    private func checkForUpdates() {
        isCheckingForUpdates = true
        updateStatusMessage = "Checking for updates..."
        
        // Simulate update check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCheckingForUpdates = false
            updateStatusMessage = "You're using the latest version"
        }
    }
    
    private var aboutSection: some View {
        VStack(spacing: 12) {
            Text("Made with ❤️")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Version: \(appVersion)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text("By Jnani Smart")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Button(action: checkForUpdates) {
                HStack {
                    if isCheckingForUpdates {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    Text("Check for Updates")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isCheckingForUpdates)
            
            if !updateStatusMessage.isEmpty {
                Text(updateStatusMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 16)
    }
    @AppStorage("encryptStorage") private var encryptStorage = false
    @State private var excludedApps: [String] = []
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    var body: some View {
        GroupBox(label: Text("Privacy").font(.headline)) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Detect sensitive content", isOn: $detectSensitiveContent)
                    .padding(.bottom, 4)
                
                if detectSensitiveContent {
                    Toggle("Don't store sensitive content", isOn: $skipSensitiveContent)
                        .padding(.leading, 20)
                        
                    Text("Sensitive content includes passwords, credit card numbers, and other personal information")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                        .padding(.bottom, 8)
                }
                
                Toggle("Encrypt clipboard storage", isOn: $encryptStorage)
                    .padding(.bottom, 4)
                
                if encryptStorage {
                    Text("All stored clipboard data will be encrypted on your device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Text("App Exclusions")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Text("Clippy won't monitor clipboard changes from these apps:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                HStack {
                    Button(action: {
                        addExcludedApp()
                    }) {
                        Label("Add App", systemImage: "plus")
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        excludedApps = []
                        saveExcludedApps()
                    }) {
                        Text("Clear All")
                    }
                    .disabled(excludedApps.isEmpty)
                }
                
                if !excludedApps.isEmpty {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(excludedApps, id: \.self) { appId in
                                HStack {
                                    Text(appNameForBundleId(appId))
                                        .font(.system(size: 12))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        removeExcludedApp(appId)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(height: min(CGFloat(excludedApps.count) * 30, 150))
                }
            }
            .padding(8)
        }
        .padding(.bottom, 16)
        .onAppear {
            loadExcludedApps()
        }
    }
    
    private func addExcludedApp() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["app"]
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.message = "Select an application to exclude from clipboard monitoring"
        openPanel.prompt = "Exclude"
        
        if openPanel.runModal() == .OK, let appUrl = openPanel.url {
            // Try to get the bundle ID using Bundle
            if let bundle = Bundle(url: appUrl) {
                // Make sure we can get a valid bundle ID
                if let bundleId = bundle.bundleIdentifier, !bundleId.isEmpty {
                    if !excludedApps.contains(bundleId) {
                        excludedApps.append(bundleId)
                        saveExcludedApps()
                        
                        // Force notification of change
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ExcludedAppsChanged"),
                            object: nil,
                            userInfo: ["excludedApps": excludedApps]
                        )
                    }
                    return
                }
            }
            
            // Fallback method if Bundle fails
            let runningApps = NSWorkspace.shared.runningApplications
            for app in runningApps {
                if app.bundleURL == appUrl, let bundleId = app.bundleIdentifier, !bundleId.isEmpty {
                    if !excludedApps.contains(bundleId) {
                        excludedApps.append(bundleId)
                        saveExcludedApps()
                        
                        // Force notification of change
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ExcludedAppsChanged"),
                            object: nil,
                            userInfo: ["excludedApps": excludedApps]
                        )
                    }
                    return
                }
            }
            
            // Alert user if we couldn't get the bundle ID
            let alert = NSAlert()
            alert.messageText = "Could not determine bundle identifier"
            alert.informativeText = "The app couldn't be excluded because its bundle identifier could not be determined."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func removeExcludedApp(_ appId: String) {
        if let index = excludedApps.firstIndex(of: appId) {
            excludedApps.remove(at: index)
            saveExcludedApps()
            
            // Force notification of change
            NotificationCenter.default.post(
                name: NSNotification.Name("ExcludedAppsChanged"),
                object: nil,
                userInfo: ["excludedApps": excludedApps]
            )
        }
    }
    
    private func saveExcludedApps() {
        UserDefaults.standard.set(excludedApps, forKey: "excludedApps")
        UserDefaults.standard.synchronize() // Force immediate save
    }
    
    private func loadExcludedApps() {
        excludedApps = UserDefaults.standard.stringArray(forKey: "excludedApps") ?? []
    }
    
    private func appNameForBundleId(_ bundleId: String) -> String {
        // Try to get the app name from the bundle ID
        let workspace = NSWorkspace.shared
        if let appUrl = workspace.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: appUrl),
           let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return appName
        }
        return bundleId
    }
}

// Structure to decode GitHub release response
private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: String
    let body: String
    let publishedAt: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
        case publishedAt = "published_at"
    }
}