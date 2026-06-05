import SwiftUI
import ApplicationServices
import ServiceManagement
import ObjectiveC

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(ClipboardAppDelegate.self) var appDelegate
    @State private var isAppDelegateInitialized = false
    
    var body: some Scene {
        Settings {
            Group {
                if isAppDelegateInitialized, let clipboardManager = appDelegate.clipboardManager {
                    SettingsView(isPresented: .constant(true))
                        .environmentObject(clipboardManager)
                        .environmentObject(appDelegate)
                } else {
                    // Show a placeholder while initializing
                    Text("Loading settings...")
                        .onAppear {
                            // Check if it's ready, and if not, wait for it
                            if appDelegate.clipboardManager != nil {
                                isAppDelegateInitialized = true
                            } else {
                                // Set up observer for when initialization completes
                                NotificationCenter.default.addObserver(forName: NSNotification.Name("AppDelegateDidInitialize"), 
                                                                      object: nil, 
                                                                      queue: .main) { _ in
                                    isAppDelegateInitialized = true
                                }
                            }
                        }
                }
            }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    appDelegate.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            // Disable Cmd+Q by replacing the appTermination command group with empty
            CommandGroup(replacing: .appTermination) {
                // Empty - this removes the default Quit command and Cmd+Q shortcut
            }
        }
    }
}

class ClipboardAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    private var statusItem: NSStatusItem?
    var clipboardManager: ClipboardManager?
    private var popover = NSPopover()
    private var shortcutManager: ShortcutManager?
    private var floatingWindow: NSPanel? // Track the floating window
    private var settingsWindow: NSPanel? // Track the settings window
    private var isShowingFloatingWindow = false
    
    // Keys for saving window positions
    private let floatingWindowPositionKey = "FloatingWindowPosition"
    private let settingsWindowPositionKey = "SettingsWindowPosition"
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // When the app becomes active (e.g., dock icon is clicked), show the floating window
        // but only if the dock icon is visible (not hidden)
        if NSApp.activationPolicy() == .regular {
            showFloatingWindow()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app icon programmatically from asset catalog
        if let appIcon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = appIcon
        } else if let iconPath = Bundle.main.path(forResource: "app_icon", ofType: "png") {
            let appIcon = NSImage(contentsOfFile: iconPath)
            NSApp.applicationIconImage = appIcon
        }
        
        // Initialize persistent settings if not already set
        if UserDefaults.standard.object(forKey: "hideDockIcon") == nil {
            UserDefaults.standard.set(true, forKey: "hideDockIcon")
        }
        
        // Apply dock icon visibility setting
        let shouldHideDockIcon = UserDefaults.standard.bool(forKey: "hideDockIcon")
        updateDockIconVisibility(hidden: shouldHideDockIcon)
        
        // Make sure to properly apply settings with a delay to ensure they take effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Double-check dock icon setting
            let shouldHideDockIcon = UserDefaults.standard.bool(forKey: "hideDockIcon")
            if shouldHideDockIcon && NSApp.activationPolicy() != .prohibited {
                self.updateDockIconVisibility(hidden: true)
            }
            
            // Double-check menu bar icon setting
            let shouldHideMenuBarIcon = UserDefaults.standard.bool(forKey: "hideMenuBarIcon") 
            if shouldHideMenuBarIcon {
                self.statusItem?.button?.isHidden = true
                print("Both dock and menu bar icons are hidden - app is accessible via keyboard shortcut only")
            }
        }
        
        // Request accessibility permissions
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            // Show alert to instruct user to enable permissions
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Please grant Accessibility access in System Settings → Privacy & Security → Accessibility to enable keyboard shortcuts. If Clippy does not appear in the list, add Clippy.app manually with the + button."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
        
        // Set up clipboard manager
        clipboardManager = ClipboardManager()
        
        // Notify that the app delegate has been initialized
        NotificationCenter.default.post(
            name: NSNotification.Name("AppDelegateDidInitialize"),
            object: self
        )
        
        // Configure popover
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        if let clipboardManager = clipboardManager {
            popover.contentViewController = NSHostingController(
                rootView: ClipboardView(clipboardManager: clipboardManager)
                    .environmentObject(clipboardManager)
                    .environmentObject(self)
            )
        }
        
        // Always create status bar item regardless of preference, since we're a menu bar app
        setupStatusBarItem()
        
        // Set up keyboard shortcut manager with user preferences
        let key = UserDefaults.standard.integer(forKey: "clipboardShortcutKey")
        let modifiers = NSEvent.ModifierFlags(rawValue:
            UInt(UserDefaults.standard.integer(forKey: "clipboardShortcutModifiers")))
        
        // Default to Cmd+Shift+V if not set
        let keyCombo = key == 0 ?
            KeyCombo(key: 9, modifiers: [.command, .shift]) :
            KeyCombo(key: key, modifiers: modifiers)
        
        shortcutManager = ShortcutManager(keyCombo: keyCombo) { [weak self] in
            self?.showFloatingWindow()
        }
        
        // Listen for "ShowClippyWindow" notification from PasteQueueManager
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ShowClippyWindow"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showFloatingWindow()
        }
        
        // Register for notifications to update shortcuts
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UpdateShortcuts"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let keyCombo = notification.userInfo?["keyCombo"] as? KeyCombo {
                // Properly clean up the old shortcut manager
                if let oldManager = self?.shortcutManager {
                    oldManager.unregisterShortcut() // Explicitly call unregister
                    self?.shortcutManager = nil
                }
                
                // Wait a moment before registering the new shortcut
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Create a new shortcut manager with the new combo
                    self?.shortcutManager = ShortcutManager(keyCombo: keyCombo) { [weak self] in
                        self?.showFloatingWindow()
                    }
                }
            }
        }
        
        // Register for notifications to update dock icon visibility
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UpdateDockIconVisibility"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let hideDockIcon = notification.userInfo?["hideDockIcon"] as? Bool {
                self?.updateDockIconVisibility(hidden: hideDockIcon)
            }
        }
        
        // Register for menu bar icon visibility changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UpdateMenuBarIconVisibility"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if notification.userInfo?["hideMenuBarIcon"] is Bool {
                // Allow hiding the menu bar icon even if dock icon is hidden
                // User can still access the app via keyboard shortcut
                self?.updateStatusBarVisibility()
            }
        }
        
        // Add automatic startup at login
        setupLoginItem(enabled: UserDefaults.standard.bool(forKey: "startAtLogin"))
        
        // Additional services setup
        setupServices()
        
        // Initialize AutoUpdater service
        initializeAutoUpdater()
        
        // Check first launch BEFORE showing anything
        let isFirstLaunch = FirstLaunchManager.shared.isFirstLaunch
        
        if isFirstLaunch {
            // First launch: show only the onboarding, no clipboard window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                OnboardingWindowController.shared.showOnboarding()
            }
            // Show clipboard window after onboarding completes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(showFloatingWindow),
                name: NSNotification.Name("OnboardingDidComplete"),
                object: nil
            )
        } else {
            // Normal launch: show floating clipboard window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showFloatingWindow()
            }
        }
    }
    
    private func setupStatusBarItem() {
        // Remove existing status item if it exists
        if statusItem != nil {
            NSStatusBar.system.removeStatusItem(statusItem!)
            statusItem = nil
        }
        
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // Use clipboard system symbol for the menu bar
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
            
            // Set button action for left click - show the clipboard history
            button.action = #selector(handleStatusItemClick)
            button.target = self
            
            // Configure to respond to right mouse clicks as well
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            // Default to showing floating window if we can't get the event
            showFloatingWindow()
            return
        }
        
        print("Status item clicked with event type: \(event.type.rawValue)")
        
        if event.type == .rightMouseUp {
            print("Right click detected, showing menu")
            
            // Create the menu on demand
            let menu = NSMenu()
            
            // Add settings item
            let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "")
            settingsItem.target = self
            menu.addItem(settingsItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // Add quit item
            let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
            quitItem.target = self
            menu.addItem(quitItem)
            
            // Show the menu under the button
            if let button = statusItem?.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button)
            }
        } else {
            // Left click - show the floating window
            print("Left click detected, showing floating window")
            showFloatingWindow()
        }
    }
    
    @objc func showHistory() {
        showFloatingWindow()
    }
    
    @objc func togglePopover(_ sender: Any? = nil) {
        showFloatingWindow()
    }
    
    @objc func openSettings() {
        // Debug print
        print("Opening settings window...")
        
        // If settings window is already open, just redirect to it in its current space
        if let window = settingsWindow, window.isVisible {
            print("Settings window already open, redirecting to it")
            // Ensure the window is visible and active in its current space
            window.makeKeyAndOrderFront(nil)
            // Activate the app but don't force it to front of other apps
            NSApp.activate(ignoringOtherApps: false)
            return
        }
        
        print("Creating new settings window with floating window style")
        
        // Create a panel similar to the floating window style
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // When window is closed, set our reference to nil
        window.delegate = self
        
        // Set title and positioning
        window.center()
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        
        // Make the window appear on top of all applications, including full screen apps
        window.level = .statusBar
        
        // Make window appear with a nice animation
        window.animationBehavior = .utilityWindow
        
        // Set transparency properties for macOS Finder-like translucency
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.alphaValue = 0  // Start transparent for fade-in animation
        
        // Hide title completely for clean look
        window.titleVisibility = .hidden
        
        // Hide standard window buttons (red, yellow, green)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Create a visual effect view with enhanced blur for macOS Finder-style glass effect
        let visualEffectView = NSVisualEffectView()
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        // Use a material that resembles Finder's translucent UI
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .withinWindow
        
        // Ensure the effect is always active for consistent appearance
        visualEffectView.state = .active
        
        // Apply system appearance instead of forcing dark mode for better integration
        visualEffectView.appearance = NSApp.effectiveAppearance
        
        // Add a subtle inner glow container for depth
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        
        // Add explicit ESC key handler for closing the window
        let keyHandler = KeyEventHandlerView()
        keyHandler.onEsc = { [weak self] in
            if let self = self {
                self.fadeOutAndCloseWindow(window)
            }
        }
        keyHandler.translatesAutoresizingMaskIntoConstraints = false
        
        // Check if clipboardManager is available before creating settings view
        guard let clipboardManager = clipboardManager else {
            // Reset the flag since we're not actually showing the window
            isShowingFloatingWindow = false
            return
        }
        
        // Create settings view
        let hostView = NSHostingView(
            rootView: SettingsView(isPresented: Binding<Bool>(
                get: { true },
                set: { newValue in
                    if !newValue {
                        self.fadeOutAndCloseWindow(window)
                    }
                }
            ))
            .environmentObject(clipboardManager)
            .environmentObject(self)
        )
        hostView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up the view hierarchy with proper layering for depth
        containerView.addSubview(hostView)
        visualEffectView.addSubview(containerView)
        visualEffectView.addSubview(keyHandler)
        
        window.contentView = visualEffectView
        
        // Make keyHandler first responder to capture key events
        window.initialFirstResponder = keyHandler
        
        // Set up constraints for proper layout
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            
            hostView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            keyHandler.widthAnchor.constraint(equalToConstant: 0),
            keyHandler.heightAnchor.constraint(equalToConstant: 0),
            keyHandler.topAnchor.constraint(equalTo: visualEffectView.topAnchor)
        ])
        
        // Apply ChatGPT-style rounded corners and glass effects
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            contentView.layer?.cornerRadius = 28
            contentView.layer?.masksToBounds = true
            
            containerView.layer?.cornerRadius = 28
            containerView.layer?.masksToBounds = true
            
            containerView.layer?.borderWidth = 0.5
            
            if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
                let gradientLayer = CAGradientLayer()
                gradientLayer.frame = containerView.bounds
                gradientLayer.cornerRadius = 28
                gradientLayer.colors = [
                    NSColor.white.withAlphaComponent(0.05).cgColor,
                    NSColor.white.withAlphaComponent(0.02).cgColor
                ]
                gradientLayer.locations = [0.0, 1.0]
                containerView.layer?.insertSublayer(gradientLayer, at: 0)
                
                NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: containerView, queue: nil) { _ in
                    gradientLayer.frame = containerView.bounds
                }
            } else {
                containerView.layer?.borderColor = NSColor.black.withAlphaComponent(0.06).cgColor
                let gradientLayer = CAGradientLayer()
                gradientLayer.frame = containerView.bounds
                gradientLayer.cornerRadius = 28
                gradientLayer.colors = [
                    NSColor.white.withAlphaComponent(0.3).cgColor,
                    NSColor.white.withAlphaComponent(0.1).cgColor
                ]
                gradientLayer.locations = [0.0, 1.0]
                containerView.layer?.insertSublayer(gradientLayer, at: 0)
                
                NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: containerView, queue: nil) { _ in
                    gradientLayer.frame = containerView.bounds
                }
            }
            
            CATransaction.commit()
        }
        
        // Set proper window dimensions
        window.setContentSize(NSSize(width: 450, height: 550))
        
        // Center the window
        window.center()
        
        // Add enhanced shadow for depth and floating appearance
        if let contentView = window.contentView, let layer = contentView.layer {
            // Create subtle shadow like visionOS
            layer.shadowOpacity = 0.3
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOffset = NSSize(width: 0, height: 0)
            layer.shadowRadius = 20
            
            // Add subtle ambient light reflection effect
            let ambientLight = CALayer()
            ambientLight.frame = contentView.bounds
            ambientLight.cornerRadius = 28
            ambientLight.masksToBounds = true
            
            // Create shine effect with gradient
            let shineGradient = CAGradientLayer()
            shineGradient.frame = contentView.bounds
            shineGradient.cornerRadius = 28
            
            // Different shine effect based on appearance
            if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                shineGradient.colors = [
                    NSColor.white.withAlphaComponent(0.05).cgColor,
                    NSColor.clear.cgColor,
                    NSColor.white.withAlphaComponent(0.02).cgColor
                ]
            } else {
                shineGradient.colors = [
                    NSColor.white.withAlphaComponent(0.2).cgColor,
                    NSColor.clear.cgColor,
                    NSColor.white.withAlphaComponent(0.1).cgColor
                ]
            }
            
            shineGradient.locations = [0.0, 0.5, 1.0]
            shineGradient.startPoint = CGPoint(x: 0, y: 1)
            shineGradient.endPoint = CGPoint(x: 1, y: 0)
            ambientLight.addSublayer(shineGradient)
            contentView.layer?.addSublayer(ambientLight)
            
            // Update shine frame when window is resized
            NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: contentView, queue: nil) { _ in
                ambientLight.frame = contentView.bounds
                shineGradient.frame = contentView.bounds
            }
            
            // Add enhanced fade-in animation
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.0
            animation.toValue = 1.0
            animation.duration = 0.25
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.layer?.add(animation, forKey: "fadeIn")
            
            // Add enhanced scale animation for visionOS-like "appear" effect
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 0.96
            scaleAnimation.toValue = 1.0
            scaleAnimation.duration = 0.25
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.layer?.add(scaleAnimation, forKey: "scaleIn")
            
            // Add subtle float animation
            let floatAnimation = CABasicAnimation(keyPath: "position.y")
            floatAnimation.fromValue = (contentView.layer?.position.y ?? 0) - 5
            floatAnimation.toValue = contentView.layer?.position.y
            floatAnimation.duration = 0.3
            floatAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.layer?.add(floatAnimation, forKey: "floatIn")
        }
        
        // Ensure app is active and window is visible
        NSApp.activate(ignoringOtherApps: true)
        
        // Restore previous position if available BEFORE showing the window
        if let savedPosition = UserDefaults.standard.string(forKey: settingsWindowPositionKey) {
            let point = NSPointFromString(savedPosition)
            window.setFrameOrigin(point)
        } else {
            window.center()
        }
        
        // Save the reference
        settingsWindow = window
        
        // Finally show the window with animation
        window.animator().alphaValue = 1.0
        window.makeKeyAndOrderFront(nil)
    }
    
    @objc func quitApp() {
        // Debug print
        print("Quitting application...")
        
        // Force quit the application
        NSApp.terminate(nil)
    }
    
    func showPopover() {
        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func closePopover() {
        popover.performClose(nil)
    }
    
    @objc func showFloatingWindow() {
        // If the window already exists, just bring it to front and return
        if let existingWindow = floatingWindow, !existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        } else if let existingWindow = floatingWindow, existingWindow.isVisible {
            // If window is already visible, just keep it open
            return
        }
        
        // Check if we're already in the process of creating a window
        if isShowingFloatingWindow {
            return
        }
        
        // Check if clipboardManager is initialized - if not, we're not ready yet
        guard let clipboardManager = clipboardManager else {
            return
        }
        
        // Set the flag to prevent multiple windows being created
        isShowingFloatingWindow = true
        
        // Create and show floating window with ChatGPT and visionOS-inspired styling
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // When window is closed, set our reference to nil
        window.delegate = self
        
        // Set title and positioning
        window.center()
        window.title = "Clipboard History"
        window.isReleasedWhenClosed = false
        
        // Make the window appear on top but handle Spotlight better
        // Use a slightly lower level than popUpMenu to avoid conflicts with Spotlight
        window.level = .floating
        
        // Check if Spotlight is active and adjust behavior if needed
        let isSpotlightActive = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.Spotlight"
        if isSpotlightActive {
            // If Spotlight is active, use a lower window level to avoid conflicts
            window.level = .normal
        }
        
        // Configure window to appear on all spaces but with better compatibility
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Prevent full-screen apps from exiting full-screen when window appears
        window.isFloatingPanel = true
        
        // Make it a non-activating panel that doesn't steal focus
        window.becomesKeyOnlyIfNeeded = true
        
        // Set this window to be not movable by background
        window.isMovableByWindowBackground = false
        
        // Add a notification observer for when Spotlight activates or deactivates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppActivationChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Make window appear with a nice animation - use popover style for modern feel
        window.animationBehavior = .utilityWindow
        
        // Set transparency properties for macOS Finder-like translucency
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.alphaValue = 0.98  // Slightly transparent overall
        
        // Hide title completely for clean look
        window.titleVisibility = .hidden
        
        // Remove standard window buttons as we'll replace them with custom ones
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Create a custom glass-like close button
        let closeButtonSize = NSSize(width: 20, height: 20)
        
        // Create a custom hover-capable close button
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let hoverNormalColor = isDarkMode
            ? NSColor.white.withAlphaComponent(0.15).cgColor
            : NSColor.black.withAlphaComponent(0.08).cgColor
            
        let hoverActiveColor = isDarkMode
            ? NSColor.white.withAlphaComponent(0.3).cgColor
            : NSColor.black.withAlphaComponent(0.15).cgColor
        
        // Create the button for use with Auto Layout
        let customCloseButton = CloseButtonWithHover(
            frame: .zero, // Will be positioned with constraints
            normalColor: hoverNormalColor,
            hoverColor: hoverActiveColor
        )
        customCloseButton.title = ""
        customCloseButton.isBordered = false
        customCloseButton.wantsLayer = true
        customCloseButton.target = self
        customCloseButton.action = #selector(fadeOutAndCloseWindow(_:))
        
        // Create a glass-like appearance for the button
        let buttonBackground = CALayer()
        buttonBackground.frame = CGRect(origin: .zero, size: closeButtonSize)
        buttonBackground.cornerRadius = closeButtonSize.width / 2
        buttonBackground.masksToBounds = true
        
        // Set semi-transparent backdrop for glass effect
        buttonBackground.backgroundColor = hoverNormalColor
        
        // Add X symbol with a better centered character
        let xSymbol = CATextLayer()
        xSymbol.frame = CGRect(x: 0, y: 0, width: closeButtonSize.width, height: closeButtonSize.height)
        xSymbol.string = "×" // Using multiplication symbol which is better centered
        xSymbol.alignmentMode = .center
        xSymbol.fontSize = 14 // Slightly larger for better visibility
        xSymbol.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        
        // Set the proper bounds and position
        xSymbol.bounds = CGRect(x: 0, y: 0, width: closeButtonSize.width, height: closeButtonSize.height)
        xSymbol.position = CGPoint(x: closeButtonSize.width/2, y: closeButtonSize.height/2)
        // Set proper anchor point for centering
        xSymbol.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        // Ensure high quality rendering with proper scale
        xSymbol.allowsFontSubpixelQuantization = true
        xSymbol.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            xSymbol.foregroundColor = NSColor.white.cgColor
        } else {
            xSymbol.foregroundColor = NSColor.black.cgColor
        }
        
        // Add layers to button
        customCloseButton.layer?.addSublayer(buttonBackground)
        buttonBackground.addSublayer(xSymbol)
        
        // Add explicit ESC key handler for closing the window
        let keyHandler = KeyEventHandlerView()
        keyHandler.onEsc = { [weak self] in
            if let self = self {
                self.fadeOutAndCloseWindow(window)
            }
        }
        keyHandler.translatesAutoresizingMaskIntoConstraints = false
        
        // Create a visual effect view with enhanced blur for macOS Finder-style glass effect
        let visualEffectView = NSVisualEffectView()
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        // Use a material that resembles Finder's translucent UI
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .withinWindow
        
        // Ensure the effect is always active for consistent appearance
        visualEffectView.state = .active
        
        // Apply system appearance instead of forcing dark mode for better integration
        visualEffectView.appearance = NSApp.effectiveAppearance
        
        // Add a subtle inner glow container for depth
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        
        // Create content host view with SwiftUI content
        let hostView = NSHostingView(
            rootView:
                // Wrap content view with key handler to ensure ESC is captured
                ClipboardView(clipboardManager: clipboardManager)
                    .environmentObject(clipboardManager)
                    .environmentObject(self)
                    .onExitCommand { [weak self] in
                        if let self = self, let window = self.floatingWindow {
                            self.fadeOutAndCloseWindow(window)
                        }
                    }
        )
        hostView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up the view hierarchy with proper layering for depth
        containerView.addSubview(hostView)
        visualEffectView.addSubview(containerView)
        visualEffectView.addSubview(keyHandler) // Add key event handler to view hierarchy
        
        // Add the close button to visual effect view (not to window.contentView)
        customCloseButton.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(customCloseButton)
        
        window.contentView = visualEffectView
        
        // Make keyHandler first responder to capture key events
        window.initialFirstResponder = keyHandler
        
        // Set up constraints for proper layout
        NSLayoutConstraint.activate([
            // Container view fills the visual effect view with small inset for border effect
            containerView.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 1),
            containerView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 1),
            containerView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -1),
            containerView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -1),
            
            // Position close button in the top-left corner
            customCloseButton.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 12),
            customCloseButton.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 16),
            customCloseButton.widthAnchor.constraint(equalToConstant: closeButtonSize.width),
            customCloseButton.heightAnchor.constraint(equalToConstant: closeButtonSize.height),
            
            // Host view fills the container view completely
            hostView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Key handler has zero size but needs to be in view hierarchy
            keyHandler.widthAnchor.constraint(equalToConstant: 0),
            keyHandler.heightAnchor.constraint(equalToConstant: 0),
            keyHandler.topAnchor.constraint(equalTo: visualEffectView.topAnchor)
        ])
        
        // Use content size constraints for better performance
        window.contentMinSize = NSSize(width: 280, height: 320)
        window.contentMaxSize = NSSize(width: 500, height: 600)
        
        // Apply ChatGPT-style rounded corners and glass effects
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            
            // Use CATransaction to batch visual changes for better performance
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            // Apply larger corner radius for ChatGPT-like appearance (28px is typical)
            contentView.layer?.cornerRadius = 28
            contentView.layer?.masksToBounds = true
            
            // Configure container view to have slightly smaller corner radius for nested effect
            containerView.layer?.cornerRadius = 27
            containerView.layer?.masksToBounds = true
            
            // Add subtle border for glass effect like visionOS
            containerView.layer?.borderWidth = 0.5
            
            // Use dynamic border color that works in both light and dark mode
            if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
                
                // Create a subtle gradient background for depth
                let gradientLayer = CAGradientLayer()
                gradientLayer.frame = containerView.bounds
                gradientLayer.cornerRadius = 27
                gradientLayer.colors = [
                    NSColor.white.withAlphaComponent(0.08).cgColor,
                    NSColor.white.withAlphaComponent(0.02).cgColor
                ]
                gradientLayer.locations = [0.0, 1.0]
                containerView.layer?.insertSublayer(gradientLayer, at: 0)
                
                // Add visionOS-inspired corner reflections - top left
                let topLeftReflection = CAGradientLayer()
                topLeftReflection.frame = CGRect(x: 0, y: containerView.bounds.height - 100, width: 100, height: 100)
                topLeftReflection.startPoint = CGPoint(x: 0, y: 0)
                topLeftReflection.endPoint = CGPoint(x: 1, y: 1)
                topLeftReflection.colors = [NSColor.white.withAlphaComponent(0.25).cgColor, NSColor.clear.cgColor]
                topLeftReflection.locations = [0.0, 1.0]
                topLeftReflection.cornerRadius = 27
                topLeftReflection.masksToBounds = true
                containerView.layer?.addSublayer(topLeftReflection)
                
                // Add visionOS-inspired corner reflections - bottom right
                let bottomRightReflection = CAGradientLayer()
                bottomRightReflection.frame = CGRect(x: containerView.bounds.width - 100, y: 0, width: 100, height: 100)
                bottomRightReflection.startPoint = CGPoint(x: 1, y: 1)
                bottomRightReflection.endPoint = CGPoint(x: 0, y: 0)
                bottomRightReflection.colors = [NSColor.white.withAlphaComponent(0.15).cgColor, NSColor.clear.cgColor]
                bottomRightReflection.locations = [0.0, 1.0]
                bottomRightReflection.cornerRadius = 27
                bottomRightReflection.masksToBounds = true
                containerView.layer?.addSublayer(bottomRightReflection)
                
                // Update reflection frames when container is resized
                NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: containerView, queue: nil) { _ in
                    gradientLayer.frame = containerView.bounds
                    topLeftReflection.frame = CGRect(x: 0, y: containerView.bounds.height - 100, width: 100, height: 100)
                    bottomRightReflection.frame = CGRect(x: containerView.bounds.width - 100, y: 0, width: 100, height: 100)
                }
            } else {
                containerView.layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
                
                // Create a subtle gradient background for depth
                let gradientLayer = CAGradientLayer()
                gradientLayer.frame = containerView.bounds
                gradientLayer.cornerRadius = 27
                gradientLayer.colors = [
                    NSColor.white.withAlphaComponent(0.4).cgColor,
                    NSColor.white.withAlphaComponent(0.2).cgColor
                ]
                gradientLayer.locations = [0.0, 1.0]
                containerView.layer?.insertSublayer(gradientLayer, at: 0)
                
                // Add visionOS-inspired corner reflections - top left
                let topLeftReflection = CAGradientLayer()
                topLeftReflection.frame = CGRect(x: 0, y: containerView.bounds.height - 100, width: 100, height: 100)
                topLeftReflection.startPoint = CGPoint(x: 0, y: 0)
                topLeftReflection.endPoint = CGPoint(x: 1, y: 1)
                topLeftReflection.colors = [NSColor.white.withAlphaComponent(0.8).cgColor, NSColor.clear.cgColor]
                topLeftReflection.locations = [0.0, 1.0]
                topLeftReflection.cornerRadius = 27
                topLeftReflection.masksToBounds = true
                containerView.layer?.addSublayer(topLeftReflection)
                
                // Add visionOS-inspired corner reflections - bottom right
                let bottomRightReflection = CAGradientLayer()
                bottomRightReflection.frame = CGRect(x: containerView.bounds.width - 100, y: 0, width: 100, height: 100)
                bottomRightReflection.startPoint = CGPoint(x: 1, y: 1)
                bottomRightReflection.endPoint = CGPoint(x: 0, y: 0)
                bottomRightReflection.colors = [NSColor.white.withAlphaComponent(0.4).cgColor, NSColor.clear.cgColor]
                bottomRightReflection.locations = [0.0, 1.0]
                bottomRightReflection.cornerRadius = 27
                bottomRightReflection.masksToBounds = true
                containerView.layer?.addSublayer(bottomRightReflection)
                
                // Update reflection frames when container is resized
                NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: containerView, queue: nil) { _ in
                    gradientLayer.frame = containerView.bounds
                    topLeftReflection.frame = CGRect(x: 0, y: containerView.bounds.height - 100, width: 100, height: 100)
                    bottomRightReflection.frame = CGRect(x: containerView.bounds.width - 100, y: 0, width: 100, height: 100)
                }
            }
            
            CATransaction.commit()
        }
        
        // Center the window with a slight vertical offset for floating appearance
        window.center()
        if let screenFrame = NSScreen.main?.visibleFrame {
            window.setFrameOrigin(NSPoint(
                x: screenFrame.midX - window.frame.width / 2,
                // Position slightly higher than center for floating appearance
                y: screenFrame.midY - window.frame.height / 2 + 20
            ))
        }
        
        // Add enhanced shadow for depth and floating appearance
        if let contentView = window.contentView, let layer = contentView.layer {
            // Create subtle shadow like visionOS
            layer.shadowOpacity = 0.3
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOffset = NSSize(width: 0, height: 0)
            layer.shadowRadius = 20
            
            // Add subtle ambient light reflection effect
            let ambientLight = CALayer()
            ambientLight.frame = contentView.bounds
            ambientLight.cornerRadius = 28
            ambientLight.masksToBounds = true
            
            // Create shine effect with gradient
            let shineGradient = CAGradientLayer()
            shineGradient.frame = contentView.bounds
            shineGradient.cornerRadius = 28
            
            // Different shine effect based on appearance
            if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                shineGradient.colors = [
                    NSColor.white.withAlphaComponent(0.05).cgColor,
                    NSColor.clear.cgColor,
                    NSColor.white.withAlphaComponent(0.02).cgColor
                ]
            } else {
                shineGradient.colors = [
                    NSColor.white.withAlphaComponent(0.2).cgColor,
                    NSColor.clear.cgColor,
                    NSColor.white.withAlphaComponent(0.1).cgColor
                ]
            }
            
            shineGradient.locations = [0.0, 0.5, 1.0]
            shineGradient.startPoint = CGPoint(x: 0, y: 1)
            shineGradient.endPoint = CGPoint(x: 1, y: 0)
            ambientLight.addSublayer(shineGradient)
            contentView.layer?.addSublayer(ambientLight)
            
            // Update shine frame when window is resized
            NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: contentView, queue: nil) { _ in
                ambientLight.frame = contentView.bounds
                shineGradient.frame = contentView.bounds
            }
            
            // Add enhanced fade-in animation
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.0
            animation.toValue = 1.0
            animation.duration = 0.25
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.layer?.add(animation, forKey: "fadeIn")
            
            // Add enhanced scale animation for visionOS-like "appear" effect
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 0.96
            scaleAnimation.toValue = 1.0
            scaleAnimation.duration = 0.25
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.layer?.add(scaleAnimation, forKey: "scaleIn")
            
            // Add subtle float animation
            let floatAnimation = CABasicAnimation(keyPath: "position.y")
            floatAnimation.fromValue = (contentView.layer?.position.y ?? 0) - 5
            floatAnimation.toValue = contentView.layer?.position.y
            floatAnimation.duration = 0.3
            floatAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.layer?.add(floatAnimation, forKey: "floatIn")
        }
        
        // Finally show the window with animation
        window.animator().alphaValue = 1.0
        window.makeKeyAndOrderFront(nil)
        
        // Restore previous position if available
        if let savedPosition = UserDefaults.standard.string(forKey: floatingWindowPositionKey) {
            let point = NSPointFromString(savedPosition)
            window.setFrameOrigin(point)
        } else {
            window.center()
            if let screenFrame = NSScreen.main?.visibleFrame {
                window.setFrameOrigin(NSPoint(
                    x: screenFrame.midX - window.frame.width / 2,
                    y: screenFrame.midY - window.frame.height / 2 + 20
                ))
            }
        }
        
        floatingWindow = window
        
        // After window is fully set up, set the flag back to false with a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isShowingFloatingWindow = false
        }
    }
    
    // Add this method to register system services
    private func setupServices() {
        // Register clipboard services with the system
        NSApplication.shared.servicesProvider = self
        NSUpdateDynamicServices()
    }
    
    // Add this method to manage login items
    private func setupLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            // Use the modern API for macOS 13+
            Task {
                do {
                    if enabled {
                        let _ = try SMAppService.mainApp.register()
                    } else {
                        let _ = try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Error managing login item: \(error.localizedDescription)")
                }
            }
        } else {
            // Use an alternative for older macOS versions
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
            let launcherAppId = "\(bundleIdentifier).LauncherApplication"
            
            // Actually use the bundleIdentifier
            SMLoginItemSetEnabled(launcherAppId as CFString, enabled)
        }
    }
    
    // Prevent app from terminating when all windows are closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Return false to keep the app running in the background
        return false
    }
    
    // Allow app to terminate when user attempts to quit
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Allow termination
        return .terminateNow
    }
    
    // Method to update status bar visibility based on user preference
    func updateStatusBarVisibility() {
        let hideMenuBarIcon = UserDefaults.standard.bool(forKey: "hideMenuBarIcon")
        
        // Store the setting
        UserDefaults.standard.set(hideMenuBarIcon, forKey: "hideMenuBarIcon")
        
        DispatchQueue.main.async {
            if hideMenuBarIcon {
                // Remove the status item if it exists
                if self.statusItem != nil {
                    NSStatusBar.system.removeStatusItem(self.statusItem!)
                    self.statusItem = nil
                    
                    // Double-check the removal was successful
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // If somehow the status item is still present, force remove it again
                        if self.statusItem != nil {
                            print("First attempt to remove menu bar icon failed, retrying...")
                            NSStatusBar.system.removeStatusItem(self.statusItem!)
                            self.statusItem = nil
                        }
                    }
                }
            } else if self.statusItem == nil {
                // Create the status item if it doesn't exist
                self.setupStatusBarItem()
                
                // Verify it was created successfully
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if self.statusItem == nil {
                        print("First attempt to create menu bar icon failed, retrying...")
                        self.setupStatusBarItem()
                    }
                }
            }
        }
    }
    
    // Add method to update dock icon visibility
    private func updateDockIconVisibility(hidden: Bool) {
        // Store the setting first
        UserDefaults.standard.set(hidden, forKey: "hideDockIcon")
        
        DispatchQueue.main.async {
            if hidden {
                // The reliable way to completely hide the dock icon:
                // First set to accessory (reduces visibility)
                NSApp.setActivationPolicy(.accessory)
                
                // Then after a tiny delay, set to prohibited (completely hides)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NSApp.setActivationPolicy(.prohibited)
                    
                    // Verify the setting took effect
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // If somehow the activation policy isn't prohibited (which can happen),
                        // try again with a different approach
                        if NSApp.activationPolicy() != .prohibited {
                            print("First attempt to hide dock icon failed, retrying...")
                            
                            // Try more aggressively with two-step approach
                            NSApp.setActivationPolicy(.accessory)
                            
                            // Process events to ensure the first change is registered
                            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
                            
                            NSApp.setActivationPolicy(.prohibited)
                            
                            // Force process events to apply the change
                            NSApp.activate(ignoringOtherApps: false)
                            let _ = NSApp.windows // Force update window list
                            
                            // Schedule another check to make triple sure
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if NSApp.activationPolicy() != .prohibited && UserDefaults.standard.bool(forKey: "hideDockIcon") {
                                    print("Third attempt to hide dock icon")
                                    NSApp.setActivationPolicy(.prohibited)
                                }
                            }
                        }
                    }
                }
            } else {
                // Show the dock icon - set to regular
                NSApp.setActivationPolicy(.regular)
                
                // Ensure windows are properly managed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Force the icon to appear by activating the app
                    NSApp.activate(ignoringOtherApps: true)
                    
                    // Update any windows if needed
                    if let window = NSApp.windows.first(where: { $0.isVisible }) {
                        window.orderFront(nil)
                    }
                }
            }
        }
    }
    
    // Handle window closing
    func windowWillClose(_ notification: Notification) {
        if let closedWindow = notification.object as? NSPanel,
           closedWindow == floatingWindow {
            // Save position
            let pos = NSStringFromPoint(closedWindow.frame.origin)
            UserDefaults.standard.set(pos, forKey: floatingWindowPositionKey)
            floatingWindow = nil
        } else if let closedWindow = notification.object as? NSPanel,
                  closedWindow == settingsWindow {
            // Save position
            let pos = NSStringFromPoint(closedWindow.frame.origin)
            UserDefaults.standard.set(pos, forKey: settingsWindowPositionKey)
            settingsWindow = nil
        }
    }
    
    @objc func fadeOutAndCloseWindow(_ sender: Any) {
        // Get the window - either from the sender or the active window
        let window: NSWindow?
        if let button = sender as? NSButton {
            // Prevent multiple clicks
            if let closeButton = button as? CloseButtonWithHover, closeButton.isCloseInProgress {
                return
            }
            if let closeButton = button as? CloseButtonWithHover {
                closeButton.isCloseInProgress = true
                closeButton.isEnabled = false
            }
            window = button.window
        } else if let windowObj = sender as? NSWindow {
            window = windowObj
        } else {
            // Try to find the settings or floating window
            window = self.settingsWindow ?? self.floatingWindow
        }

        // Save position before closing
        if let window = window {
            if window == self.settingsWindow {
                let pos = NSStringFromPoint(window.frame.origin)
                UserDefaults.standard.set(pos, forKey: settingsWindowPositionKey)
            } else if window == self.floatingWindow {
                let pos = NSStringFromPoint(window.frame.origin)
                UserDefaults.standard.set(pos, forKey: floatingWindowPositionKey)
            }
        }

        // Animate fade-out
        if let window = window {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = 0
            }, completionHandler: {
                if self.settingsWindow == window {
                    self.settingsWindow = nil
                } else if self.floatingWindow == window {
                    self.floatingWindow = nil
                }
                window.close()
            })
        }
    }
    
    // Add a public method to clear the clipboard history
    func clearHistory() {
        print("Clearing clipboard history from AppDelegate...")
        clipboardManager?.clearHistory()
        
        // Post a notification that the history was cleared
        NotificationCenter.default.post(
            name: Notification.Name("HistoryCleared"),
            object: nil
        )
    }
    
    // Initialize AutoUpdater service
    private func initializeAutoUpdater() {
        // Enable auto-update checking by default
        let autoUpdater = AutoUpdater.shared
        
        // Load user preference for auto-updates (default to enabled)
        let autoUpdateEnabled = UserDefaults.standard.object(forKey: "autoUpdateEnabled") as? Bool ?? true
        
        // Use Task to call the main actor method
        Task { @MainActor in
            autoUpdater.enableAutoCheck(autoUpdateEnabled)
        }
        
        print("AutoUpdater initialized with auto-check: \(autoUpdateEnabled)")
    }
    
    // Handle app activation changes to adjust window behavior when Spotlight appears
    @objc func handleAppActivationChange(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let bundleID = app.bundleIdentifier,
           let window = self.floatingWindow {
           
            if bundleID == "com.apple.Spotlight" {
                // Lower window level when Spotlight is active
                window.level = .normal
            } else {
                // Restore window level for other apps
                window.level = .floating
            }
        }
    }
    
    func showSettingsWindow() {
        guard let clipboardManager = clipboardManager else { return }
        
        // Get current menu position
        guard let screen = NSScreen.main else { return }
        let menuXPosition = popover.contentViewController?.view.window?.frame.origin.x ?? screen.frame.midX
        let screenMidX = screen.frame.midX
        
        // Position settings window on opposite side of screen from menu
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        settingsWindow.contentViewController = NSHostingController(
            rootView: SettingsView(isPresented: .constant(true))
                .environmentObject(clipboardManager)
                .environmentObject(self)
        )
        
        settingsWindow.center()
        
        // Adjust position based on menu location
        let newX = menuXPosition < screenMidX ? 
            screen.frame.maxX - settingsWindow.frame.width - 20 : 
            20
        
        settingsWindow.setFrameOrigin(NSPoint(x: newX, y: settingsWindow.frame.origin.y))
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// KeyEventHandlerView for intercepting ESC key events
class KeyEventHandlerView: NSView {
    var onEsc: (() -> Void)?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 49, 53, 76, 125, 126:
            let keyEvent = ClipboardHistoryKeyEvent(keyCode: event.keyCode)
            NotificationCenter.default.post(name: .clipboardHistoryKeyDown, object: keyEvent)

            if keyEvent.handled {
                return
            }

            if event.keyCode == 53 { // ESC key
                onEsc?()
                return
            }
            fallthrough
        default:
            break
        }

        super.keyDown(with: event)
    }
}

// Class for custom hover-capable close button
class CloseButtonWithHover: NSButton {
    var normalColor: CGColor
    var hoverColor: CGColor
    var isCloseInProgress = false
    
    init(frame: NSRect, normalColor: CGColor, hoverColor: CGColor) {
        self.normalColor = normalColor
        self.hoverColor = hoverColor
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Use updateTrackingAreas so the tracking rect matches the actual bounds after layout
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil)
        )
    }
    
    override func mouseEntered(with event: NSEvent) {
        if let bgLayer = self.layer?.sublayers?.first {
            bgLayer.backgroundColor = hoverColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if let bgLayer = self.layer?.sublayers?.first {
            bgLayer.backgroundColor = normalColor
        }
    }
}
