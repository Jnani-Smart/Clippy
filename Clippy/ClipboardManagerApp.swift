import SwiftUI
import ApplicationServices
import ServiceManagement

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(ClipboardAppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class ClipboardAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    private var statusItem: NSStatusItem?
    var clipboardManager: ClipboardManager?
    private var popover = NSPopover()
    private var shortcutManager: ShortcutManager?
    private var floatingWindow: NSPanel? // Track the floating window
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app icon programmatically from asset catalog
        if let appIcon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = appIcon
        } else if let iconPath = Bundle.main.path(forResource: "app_icon", ofType: "png") {
            let appIcon = NSImage(contentsOfFile: iconPath)
            NSApp.applicationIconImage = appIcon
        }
        
        // Request accessibility permissions
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            // Show alert to instruct user to enable permissions
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Please grant accessibility permissions in System Preferences → Security & Privacy → Privacy → Accessibility to enable keyboard shortcuts."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Later")
            
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
        
        // Set up clipboard manager
        clipboardManager = ClipboardManager()
        
        // Configure popover
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ClipboardView(clipboardManager: clipboardManager!)
                .environmentObject(clipboardManager!)
        )
        
        // Set up status bar item based on user preference
        updateStatusBarVisibility()
        
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
        
        // Set initial dock icon visibility
        let hideDockIcon = UserDefaults.standard.bool(forKey: "hideDockIcon")
        updateDockIconVisibility(hidden: hideDockIcon)
        
        // Add automatic startup at login
        setupLoginItem(enabled: UserDefaults.standard.bool(forKey: "startAtLogin"))
        
        // Additional services setup
        setupServices()
        
        // Observe changes to the hideMenuBarIcon preference
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusBarVisibility()
        }
    }
    
    @objc func togglePopover() {
        // Show clipboard history for any click type
        showFloatingWindow()
    }
    
    @objc func openSettings() {
        // Create a settings window
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure the window
        settingsWindow.center()
        settingsWindow.title = "Settings"
        
        // Create a SwiftUI view for settings
        let settingsView = SettingsView(isPresented: .constant(true))
        
        // Set the content view
        settingsWindow.contentView = NSHostingView(rootView: settingsView)
        
        // Show the window
        settingsWindow.makeKeyAndOrderFront(nil)
    }
    
    @objc func quitApp() {
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
    
    func showFloatingWindow() {
        // If the window already exists, just bring it to front and return
        if let existingWindow = floatingWindow, !existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        } else if let existingWindow = floatingWindow, existingWindow.isVisible {
            // If window is already visible, just keep it open
            return
        }
        
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
        
        // Make the window appear on top of ALL other apps, including full screen apps
        window.level = .popUpMenu // Use very high level (just below .screenSaver)
        
        // Configure window to appear on all spaces including full-screen apps
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Prevent full-screen apps from exiting full-screen when window appears
        window.isFloatingPanel = true
        
        // Make it a non-activating panel that doesn't steal focus
        window.becomesKeyOnlyIfNeeded = true
        
        // Set this window to be not movable by background
        window.isMovableByWindowBackground = false
        
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
        let hoverNormalColor = NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white.withAlphaComponent(0.15).cgColor
            : NSColor.black.withAlphaComponent(0.08).cgColor
            
        let hoverActiveColor = NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
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
        
        if NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
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
        
        // Class for custom hover-capable close button
        class CloseButtonWithHover: NSButton {
            var normalColor: CGColor
            var hoverColor: CGColor
            
            init(frame: NSRect, normalColor: CGColor, hoverColor: CGColor) {
                self.normalColor = normalColor
                self.hoverColor = hoverColor
                super.init(frame: frame)
                
                // Add tracking area for hover events
                self.addTrackingArea(NSTrackingArea(
                    rect: self.bounds,
                    options: [.mouseEnteredAndExited, .activeInActiveApp],
                    owner: self,
                    userInfo: nil)
                )
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
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
        
        // Create a visual effect view with enhanced blur for macOS Finder-style glass effect
        let visualEffectView = NSVisualEffectView()
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        // Use a material that resembles Finder's sidebar
        visualEffectView.material = .sidebar  // More like Finder's translucent sidebar
        visualEffectView.blendingMode = .behindWindow
        
        // Ensure the effect is always active for consistent appearance
        visualEffectView.state = .active
        
        // Apply system appearance instead of forcing dark mode for better integration
        visualEffectView.appearance = NSAppearance.current
        
        // Add a subtle inner glow container for depth
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        
        // Create content host view with SwiftUI content
        let hostView = NSHostingView(
            rootView:
                // Wrap content view with key handler to ensure ESC is captured
                ClipboardView(clipboardManager: clipboardManager!)
                    .environmentObject(clipboardManager!)
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
            if NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
                // Create a subtle gradient background for depth
                let gradientLayer = CAGradientLayer()
                gradientLayer.frame = containerView.bounds
                gradientLayer.cornerRadius = 27
                gradientLayer.colors = [
                    NSColor.white.withAlphaComponent(0.05).cgColor,
                    NSColor.white.withAlphaComponent(0.02).cgColor
                ]
                gradientLayer.locations = [0.0, 1.0]
                containerView.layer?.insertSublayer(gradientLayer, at: 0)
                
                // Update gradient frame when container is resized
                NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: containerView, queue: nil) { _ in
                    gradientLayer.frame = containerView.bounds
                }
            } else {
                containerView.layer?.borderColor = NSColor.black.withAlphaComponent(0.06).cgColor
                // Create a subtle gradient background for depth
                let gradientLayer = CAGradientLayer()
                gradientLayer.frame = containerView.bounds
                gradientLayer.cornerRadius = 27
                gradientLayer.colors = [
                    NSColor.white.withAlphaComponent(0.3).cgColor,
                    NSColor.white.withAlphaComponent(0.1).cgColor
                ]
                gradientLayer.locations = [0.0, 1.0]
                containerView.layer?.insertSublayer(gradientLayer, at: 0)
                
                // Update gradient frame when container is resized
                NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: containerView, queue: nil) { _ in
                    gradientLayer.frame = containerView.bounds
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
            // Create subtle shadow like macOS Finder
            layer.shadowOpacity = 0.25
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOffset = NSSize(width: 0, height: -1)
            layer.shadowRadius = 15
            
            // Add subtle fade-in animation
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.0
            animation.toValue = 1.0
            animation.duration = 0.18
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.layer?.add(animation, forKey: "fadeIn")
            
            // Add subtle scale animation
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 0.98
            scaleAnimation.toValue = 1.0
            scaleAnimation.duration = 0.18
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.layer?.add(scaleAnimation, forKey: "scaleIn")
        }
        
        // Finally show the window with animation
        window.animator().alphaValue = 1.0
        window.makeKeyAndOrderFront(nil)
        
        floatingWindow = window
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
                        let _ = try await SMAppService.mainApp.register()
                    } else {
                        let _ = try await SMAppService.mainApp.unregister()
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
    
    // Prevent app from terminating when user attempts to quit
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Hide all windows instead of terminating
        NSApplication.shared.windows.forEach { $0.close() }
        
        // Return cancel to prevent termination
        return .terminateCancel
    }
    
    // Method to update status bar visibility based on user preference
    func updateStatusBarVisibility() {
        let hideMenuBarIcon = UserDefaults.standard.bool(forKey: "hideMenuBarIcon")
        
        if hideMenuBarIcon {
            // Remove the status item if it exists
            if statusItem != nil {
                NSStatusBar.system.removeStatusItem(statusItem!)
                statusItem = nil
            }
        } else if statusItem == nil {
            // Create the status item if it doesn't exist
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = statusItem?.button {
                // Use clipboard system symbol for the menu bar
                button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard")
                button.image?.size = NSSize(width: 18, height: 18)
                button.image?.isTemplate = true
                
                // Set up click handling to show clipboard history
                button.action = #selector(togglePopover)
                
                // No menu needed, just handle clicks directly
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
        }
    }
    
    // Add method to update dock icon visibility
    private func updateDockIconVisibility(hidden: Bool) {
        if hidden {
            // Hide the dock icon
            NSApp.setActivationPolicy(.accessory)
        } else {
            // Show the dock icon
            NSApp.setActivationPolicy(.regular)
        }
    }
    
    // Handle window closing
    func windowWillClose(_ notification: Notification) {
        if let closedWindow = notification.object as? NSPanel,
           closedWindow == floatingWindow {
            floatingWindow = nil
        }
    }
    
    @objc func fadeOutAndCloseWindow(_ sender: Any) {
        // Get the window either from the sender or use the floatingWindow
        let windowToClose: NSWindow?
        
        if let button = sender as? NSButton, let buttonWindow = button.window {
            windowToClose = buttonWindow
        } else if let window = sender as? NSWindow {
            windowToClose = window
        } else {
            windowToClose = floatingWindow
        }
        
        guard let window = windowToClose else { return }
        
        // Fade out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2  // Short fade duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            // Close the window after animation completes
            window.close()
            if window == self.floatingWindow {
                self.floatingWindow = nil
            }
        })
    }
}

// KeyEventHandlerView for intercepting ESC key events
class KeyEventHandlerView: NSView {
    var onEsc: (() -> Void)?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onEsc?()
        } else {
            super.keyDown(with: event)
        }
    }
}
