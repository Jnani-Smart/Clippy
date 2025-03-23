import SwiftUI
import ObjectiveC

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
        
        // Make the button handle mouse events
        class CloseButtonMouseHandler: NSObject {
            var normalColor: CGColor
            var hoverColor: CGColor
            
            init(normalColor: CGColor, hoverColor: CGColor) {
                self.normalColor = normalColor
                self.hoverColor = hoverColor
                super.init()
            }
            
            @objc func mouseEntered(with event: NSEvent) {
                if let button = event.trackingArea?.owner as? NSButton,
                   let bgLayer = button.layer?.sublayers?.first {
                    bgLayer.backgroundColor = hoverColor
                }
            }
            
            @objc func mouseExited(with event: NSEvent) {
                if let button = event.trackingArea?.owner as? NSButton,
                   let bgLayer = button.layer?.sublayers?.first {
                    bgLayer.backgroundColor = normalColor
                }
            }
        }
        
        // Create a mouse handler and attach it to the button
        let mouseHandler = CloseButtonMouseHandler(normalColor: hoverNormalColor, hoverColor: hoverActiveColor)
        
        // Store the mouse handler to prevent it from being deallocated
        objc_setAssociatedObject(
            closeButton,
            "mouseHandler",
            mouseHandler,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Add tracking area for hover effects
        closeButton.addTrackingArea(NSTrackingArea(
            rect: closeButton.bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: mouseHandler,
            userInfo: nil)
        )
        
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
        
        // Handle mouse events for hover effect
        @objc func mouseEntered(with event: NSEvent) {
            guard let button = event.trackingArea?.owner as? NSButton else { return }
            if let bgLayer = button.layer?.sublayers?.first {
                bgLayer.backgroundColor = hoverColor
            }
        }
        
        @objc func mouseExited(with event: NSEvent) {
            guard let button = event.trackingArea?.owner as? NSButton else { return }
            if let bgLayer = button.layer?.sublayers?.first {
                bgLayer.backgroundColor = normalColor
            }
        }
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
    @EnvironmentObject private var clipboardManager: ClipboardManager
    @State private var keyEventMonitor: Any?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Custom title bar with visionOS styling - add padding at top for close button
                ZStack(alignment: .center) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .frame(height: 50)
                .padding(.top, 5) // Add padding for close button
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
                }
                .padding(.top, 5)
            }
            .frame(width: 500, height: 430)
            
            // Add close button in the top-left corner
            CloseButtonRepresentable(onClose: {
                isPresented = false
            })
            .frame(width: 24, height: 24)
            .offset(x: 10, y: 10)
        }
        // Use hudWindow material like the floating window instead of sidebar
        .background(
            ZStack {
                // Premium glass effect background with enhanced contrast for foreground
                SettingsVisualEffectView(material: .titlebar, blendingMode: .behindWindow)
                
                // Slightly darker overlay for better foreground visibility
                Color.black.opacity(0.14)
                
                // Subtle gradient for dimension
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.05),
                        Color.black.opacity(0.02)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
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
                
                // Quit button
                VisionOSButton(title: "Quit Clippy", role: .destructive, isInProgress: $isQuitInProgress) {
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
            .padding(20)
        }
    }
    
    // Privacy settings with visionOS-inspired styling
    private var privacySettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VisionOSGroupBox(title: "Privacy Settings") {
                    VStack(alignment: .leading, spacing: 16) {
                        VisionOSToggle(
                            title: "Detect sensitive content", 
                            description: "Detect sensitive data like credit cards, emails, and passwords",
                            isOn: $detectSensitiveContent
                        )
                        
                        VisionOSToggle(
                            title: "Skip storing sensitive content", 
                            description: "Automatically skip storing detected sensitive content",
                            isOn: $skipSensitiveContent
                        )
                        .disabled(!detectSensitiveContent)
                        .padding(.leading, 20)
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("Your clipboard data is stored locally on your Mac and is never sent to any server.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                VisionOSButton(title: "Clear All History", role: .destructive, isInProgress: $isClearHistoryInProgress) {
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
            .padding(20)
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
                            .padding(.top, 4)
                        
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                            VisionOSCategoryRow(name: "Code", icon: "chevron.left.forwardslash.chevron.right", color: .blue)
                            VisionOSCategoryRow(name: "URLs", icon: "link", color: .green)
                            VisionOSCategoryRow(name: "Images", icon: "photo", color: .orange)
                            VisionOSCategoryRow(name: "Text", icon: "doc.text", color: .secondary)
                        }
                    }
                }
            }
            .padding(20)
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
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }
    
    // Data management settings with visionOS-inspired styling
    private var dataManagementView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VisionOSGroupBox(title: "Clipboard Data") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Export your clipboard history to a file or import from a previously exported file.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        HStack(spacing: 12) {
                            VisionOSButton(title: "Export Clipboard History", role: nil, isInProgress: $isExporting) {
                                guard !isExporting else { return }
                                isExporting = true
                                exportHistory()
                                // Reset after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isExporting = false
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            VisionOSButton(title: "Import Clipboard History", role: nil, isInProgress: $isImporting) {
                                guard !isImporting else { return }
                                isImporting = true
                                importHistory()
                                // Reset after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isImporting = false
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(20)
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
}

// VisionOS-inspired components

// Group Box with visionOS styling
struct VisionOSGroupBox<Content: View>: View {
    let title: String
    let content: Content
    
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
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
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
    
    init(title: String, role: ButtonRole? = nil, isInProgress: Binding<Bool>? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
        self._isInProgress = isInProgress ?? .constant(false)
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .opacity(isInProgress ? 0.7 : 1.0)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(role == .destructive ? .red : .accentColor)
        .disabled(isInProgress)
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