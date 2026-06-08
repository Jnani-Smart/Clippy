import Foundation
import SwiftUI
import Combine
import CoreGraphics
import AppKit
import QuartzCore
import ApplicationServices

/// PasteQueueManager handles the FIFO (First-In, First-Out) paste queue functionality.
/// Items added to the queue will be pasted in order - each paste operation advances to the next item.
class PasteQueueManager: ObservableObject {
    static let shared = PasteQueueManager()
    static let copyShortcutKeyDefaultsKey = "pasteQueueCopyShortcutKey"
    static let copyShortcutModifiersDefaultsKey = "pasteQueueCopyShortcutModifiers"
    static let pasteShortcutKeyDefaultsKey = "pasteQueuePasteShortcutKey"
    static let pasteShortcutModifiersDefaultsKey = "pasteQueuePasteShortcutModifiers"
    static let updateShortcutsNotification = Notification.Name("UpdatePasteQueueShortcuts")
    static let defaultCopyShortcut = KeyCombo(key: .c, modifiers: [.control, .option])
    static let defaultPasteShortcut = KeyCombo(key: .v, modifiers: [.control, .option])
    
    /// The items currently in the paste queue, in order (first item will be pasted first)
    @Published var queueItems: [ClipboardItem] = []
    
    /// Whether the paste queue mode is active
    @Published var isQueueModeActive: Bool = false
    
    /// Index of the current item to paste (0-based)
    @Published var currentIndex: Int = 0
    
    /// Whether a paste operation is currently in progress
    @Published var isPasting: Bool = false
    
    /// Track if we just queued an item (for animation feedback)
    @Published var justQueued: Bool = false
    
    /// Current shortcut used to activate queue capture mode
    @Published private(set) var copyShortcut: KeyCombo = PasteQueueManager.defaultCopyShortcut
    
    /// Current shortcut used to paste the next queued item
    @Published private(set) var pasteShortcut: KeyCombo = PasteQueueManager.defaultPasteShortcut
    
    /// Maximum items allowed in the queue
    let maxQueueSize: Int = 50
    
    /// Shortcut manager for queue copy shortcut
    private var queueCopyShortcutManager: ShortcutManager?
    
    /// Shortcut manager for queue paste shortcut
    private var queuePasteShortcutManager: ShortcutManager?
    
    /// Flag to track if we are waiting for a clipboard update to add to queue
    private var pendingQueueAdd: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        loadShortcutPreferences()
        setupGlobalShortcuts()
        setupShortcutPreferenceMonitoring()
        setupClipboardMonitoring()
    }
    
    private func setupClipboardMonitoring() {
        // Wait briefly for ClipboardManager.shared to be available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, let clipboardManager = ClipboardManager.shared else { return }
            
            clipboardManager.$clipboardItems
                .dropFirst() // Skip initial value
                .sink { [weak self] items in
                    guard let self = self, let newItem = items.first else { return }
                    
                    // Only add to queue if queue mode is active and it's not an internal operation
                    // Note: ClipboardManager handles isInternalPasteboardChange internally, so updates here are "external"
                    if self.isQueueModeActive && !self.isPasting {
                        // Check if we just added this item (avoid duplicates if multiple updates trigger)
                        if let lastItem = self.queueItems.last, lastItem.id == newItem.id {
                            return
                        }
                        
                        self.addToQueue(newItem)
                        
                        #if DEBUG
                        print("✅ Captured copy for queue: \(newItem.preview.prefix(20))...")
                        #endif
                    }
                }
                .store(in: &self.cancellables)
        }
    }
    
    private func setupGlobalShortcuts() {
        queueCopyShortcutManager = ShortcutManager(keyCombo: copyShortcut) { [weak self] in
            self?.handleCopyToQueue()
        }
        
        queuePasteShortcutManager = ShortcutManager(keyCombo: pasteShortcut) { [weak self] in
            self?.handlePasteFromQueue()
        }
    }
    
    private func setupShortcutPreferenceMonitoring() {
        NotificationCenter.default.addObserver(
            forName: Self.updateShortcutsNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadGlobalShortcuts()
        }
    }
    
    private func reloadGlobalShortcuts() {
        loadShortcutPreferences()
        
        queueCopyShortcutManager?.unregisterShortcut()
        queueCopyShortcutManager = nil
        queuePasteShortcutManager?.unregisterShortcut()
        queuePasteShortcutManager = nil
        
        setupGlobalShortcuts()
    }
    
    private func loadShortcutPreferences() {
        copyShortcut = Self.keyCombo(
            keyDefaultsKey: Self.copyShortcutKeyDefaultsKey,
            modifiersDefaultsKey: Self.copyShortcutModifiersDefaultsKey,
            defaultKeyCombo: Self.defaultCopyShortcut
        )
        pasteShortcut = Self.keyCombo(
            keyDefaultsKey: Self.pasteShortcutKeyDefaultsKey,
            modifiersDefaultsKey: Self.pasteShortcutModifiersDefaultsKey,
            defaultKeyCombo: Self.defaultPasteShortcut
        )
    }
    
    private static func keyCombo(
        keyDefaultsKey: String,
        modifiersDefaultsKey: String,
        defaultKeyCombo: KeyCombo
    ) -> KeyCombo {
        let savedKey = UserDefaults.standard.object(forKey: keyDefaultsKey) as? Int
        let savedModifiers = UserDefaults.standard.object(forKey: modifiersDefaultsKey) as? UInt
        
        guard let savedKey, let savedModifiers, savedKey != 0 else {
            return defaultKeyCombo
        }
        
        return KeyCombo(key: savedKey, modifiers: NSEvent.ModifierFlags(rawValue: savedModifiers))
    }
    
    private func handleCopyToQueue() {
        #if DEBUG
        print("⌨️ \(copyShortcut.displayString) pressed - Activating Queue Mode")
        #endif
        
        // 1. Activate queue mode
        isQueueModeActive = true
                
        // 2. Open Clippy Window to show the queue
        NotificationCenter.default.post(name: Notification.Name("ShowClippyWindow"), object: nil)
        
        // 3. Optional: Provide visual feedback or switch tab to Queue if implementation allows
        // (Notification handles window opening, View logic should handle tab selection if needed)
    }
    
    private func handlePasteFromQueue() {
        #if DEBUG
        print("⌨️ \(pasteShortcut.displayString) pressed - Paste Triggered")
        #endif
        
        if queueItems.isEmpty {
            // If queue is empty, Just open the window
            NotificationCenter.default.post(name: Notification.Name("ShowClippyWindow"), object: nil)
        } else {
            pasteNext()
        }
    }
    
    // SimulateCopy removed as we rely on user manually pressing Cmd+C after activation
    
    // MARK: - Queue Management
    
    /// Add an item to the end of the paste queue
    func addToQueue(_ item: ClipboardItem) {
        // ... (rest of the method unchanged, but included for context in replacement if needed, 
        // effectively we just need to confirm the logic below is robust)
        
        guard queueItems.count < maxQueueSize else { return }
        
        // Check for duplicates by ID in the queue to avoid re-adding same item instantly
        guard !queueItems.contains(where: { $0.id == item.id }) else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.queueItems.append(item)
            
            // Queue mode should already be active, but ensure it
            if !self.isQueueModeActive {
                self.isQueueModeActive = true
            }
            
            // Trigger animation feedback
            self.justQueued = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.justQueued = false
            }
        }
    }
    
    /// Remove an item from the queue
    func removeFromQueue(_ item: ClipboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.queueItems.firstIndex(where: { $0.id == item.id }) {
                self.queueItems.remove(at: index)
                
                // Adjust current index if needed
                if self.currentIndex >= self.queueItems.count {
                    self.currentIndex = max(0, self.queueItems.count - 1)
                }
                
                // Disable queue mode if no items left (User requirement: restore to inactive when empty)
                if self.queueItems.isEmpty {
                    self.isQueueModeActive = false
                    self.currentIndex = 0
                }
            }
        }
    }
    
    /// Move an item within the queue
    func moveItems(from source: IndexSet, to destination: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.queueItems.move(fromOffsets: source, toOffset: destination)
        }
    }
    
    /// Clear the entire paste queue
    func clearQueue() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.queueItems.removeAll()
            self.currentIndex = 0
            self.isQueueModeActive = false
        }
    }
    
    /// Get the current item to be pasted
    var currentItem: ClipboardItem? {
        guard !queueItems.isEmpty, currentIndex < queueItems.count else {
            return nil
        }
        return queueItems[currentIndex]
    }
    
    /// Check if an item is in the queue
    func isInQueue(_ item: ClipboardItem) -> Bool {
        return queueItems.contains(where: { $0.id == item.id })
    }
    
    /// Get the position of an item in the queue (1-based for display)
    func positionInQueue(_ item: ClipboardItem) -> Int? {
        guard let index = queueItems.firstIndex(where: { $0.id == item.id }) else {
            return nil
        }
        return index + 1
    }
    
    // MARK: - Paste Operations
    
    /// Paste the current item and advance to the next
    @discardableResult
    func pasteNext() -> Bool {
        // Only require that we have items and aren't currently pasting
        guard let item = currentItem, !isPasting else { return false }
        
        isPasting = true
        
        // Auto-enable queue mode if pasting (though usually it's already active)
        if !isQueueModeActive {
            isQueueModeActive = true
        }
        
        // Copy the current item to pasteboard
        copyItemToPasteboard(item)
        
        // Check if this is the last item - only hide window if queue will be empty after paste
        let isLastItem = queueItems.count <= 1
        
        if isLastItem {
            // Hide the Clippy window only when pasting the last item
            hideClippyWindow()
        }
        
        // Simulate paste after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.simulatePaste()
            
            // Advance to next item after paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.advanceQueue()
                
                // Re-show the window if there are still items remaining
                if let self = self, !self.queueItems.isEmpty {
                    NotificationCenter.default.post(name: Notification.Name("ShowClippyWindow"), object: nil)
                }
            }
        }
        
        return true
    }
    
    /// Hide the Clippy window so paste goes to the previously focused app
    private func hideClippyWindow() {
        DispatchQueue.main.async {
            // Hide the app
            NSApplication.shared.hide(nil)
            
            // Find and close/hide the visible window
            if let window = NSApplication.shared.windows.first(where: { $0.isVisible }) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.1
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().alphaValue = 0.0
                }, completionHandler: {
                    window.orderOut(nil)
                    window.alphaValue = 1.0 // Reset for next time
                })
            }
        }
    }
    
    /// Advance to the next item in the queue without pasting
    private func advanceQueue() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Remove the just-pasted item from queue
            if !self.queueItems.isEmpty {
                self.queueItems.removeFirst()
                
                // Disable queue mode if no items left
                if self.queueItems.isEmpty {
                    self.isQueueModeActive = false
                    self.currentIndex = 0
                }
            }
            
            self.isPasting = false
        }
    }
    
    /// Copy an item to the system pasteboard
    private func copyItemToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            if let text = item.text {
                pasteboard.setString(text, forType: .string)
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
    }
    
    /// Simulate the paste keyboard shortcut (Cmd+V)
    private func simulatePaste() {
        DispatchQueue.global(qos: .userInteractive).async {
            // Small delay to ensure the window is hidden and previous app is focused
            Thread.sleep(forTimeInterval: 0.05)
            
            // Use nil source for clean event generation
            
            // Cmd+V (Key 0x09)
            guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) else { return }
            keyDown.flags = .maskCommand
            
            guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else { return }
            keyUp.flags = .maskCommand
            
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Toggle Queue Mode
    func deactivateQueueMode() {
        DispatchQueue.main.async { [weak self] in
            self?.isQueueModeActive = false
        }
    }
    
    func toggleQueueMode() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.isQueueModeActive {
                self.isQueueModeActive = false
            } else {
                self.isQueueModeActive = true
            }
            
            #if DEBUG
            print("🔄 Queue mode: \(self.isQueueModeActive ? "ON" : "OFF")")
            #endif
        }
    }
    
    // MARK: - Statistics
    
    /// Number of items in the queue
    var itemCount: Int {
        return queueItems.count
    }
    
    /// Number of items remaining to paste
    var remainingCount: Int {
        return queueItems.count
    }
}
