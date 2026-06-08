import Foundation
import Cocoa
import Carbon

struct KeyCombo: Equatable {
    let key: Int
    let modifiers: NSEvent.ModifierFlags
    
    init(key: Key, modifiers: NSEvent.ModifierFlags) {
        self.key = key.rawValue
        self.modifiers = modifiers
    }
    
    // Add a different constructor that works with raw integers
    init(key: Int, modifiers: NSEvent.ModifierFlags) {
        // Convert Int to Key enum value if possible, otherwise use a direct integer value
        if let keyEnum = Key(rawValue: key) {
            self.key = keyEnum.rawValue
        } else {
            self.key = key
        }
        self.modifiers = modifiers
    }
    
    // Add Equatable conformance
    static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
        return lhs.key == rhs.key && lhs.modifiers.rawValue == rhs.modifiers.rawValue
    }
}

enum Key: Int {
    case a = 0x00
    case s = 0x01
    case d = 0x02
    case f = 0x03
    case h = 0x04
    case g = 0x05
    case z = 0x06
    case x = 0x07
    case c = 0x08
    case v = 0x09
    case b = 0x0B
    case q = 0x0C
    case w = 0x0D
    case e = 0x0E
    case r = 0x0F
    case y = 0x10
    case t = 0x11
    case one = 0x12
    case two = 0x13
    case three = 0x14
    case four = 0x15
    case six = 0x16
    case five = 0x17
    case equals = 0x18
    case nine = 0x19
    case seven = 0x1A
    case minus = 0x1B
    case eight = 0x1C
    case zero = 0x1D
    case rightBracket = 0x1E
    case o = 0x1F
    case u = 0x20
    case leftBracket = 0x21
    case i = 0x22
    case p = 0x23
    case l = 0x25
    case j = 0x26
    case quote = 0x27
    case k = 0x28
    case semicolon = 0x29
    case backslash = 0x2A
    case comma = 0x2B
    case slash = 0x2C
    case n = 0x2D
    case m = 0x2E
    case period = 0x2F
    case grave = 0x32
    case space = 0x31
    case escape = 0x35
}

// Add this extension to convert AppKit modifier flags to Carbon modifier flags
extension NSEvent.ModifierFlags {
    var carbonFlags: UInt32 {
        var carbonFlags: UInt32 = 0
        
        if contains(.command) {
            carbonFlags |= UInt32(cmdKey)
        }
        if contains(.option) {
            carbonFlags |= UInt32(optionKey)
        }
        if contains(.control) {
            carbonFlags |= UInt32(controlKey)
        }
        if contains(.shift) {
            carbonFlags |= UInt32(shiftKey)
        }
        
        return carbonFlags
    }
}

class ShortcutManager {
    private var hotKeyRef: EventHotKeyRef?
    private let keyCombo: KeyCombo
    private let action: () -> Void
    private let hotKeyID: UInt32
    private(set) var registrationError: OSStatus?
    
    var isRegistered: Bool {
        hotKeyRef != nil && registrationError == nil
    }
    
    // Static counter to generate unique IDs for each shortcut
    private static var nextHotKeyID: UInt32 = 1
    private static var registeredManagers: [UInt32: ShortcutManager] = [:]
    private static var sharedEventHandler: EventHandlerRef?
    
    init(keyCombo: KeyCombo, action: @escaping () -> Void) {
        self.keyCombo = keyCombo
        self.action = action
        self.hotKeyID = ShortcutManager.nextHotKeyID
        ShortcutManager.nextHotKeyID += 1
        
        registerShortcut()
        if isRegistered {
            ShortcutManager.registeredManagers[self.hotKeyID] = self
        }
    }
    
    deinit {
        unregisterShortcut()
        ShortcutManager.registeredManagers.removeValue(forKey: hotKeyID)
    }
    
    private static func installSharedEventHandlerIfNeeded() {
        guard sharedEventHandler == nil else { return }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (handlerRef, eventRef, userData) -> OSStatus in
                var hotkeyID = EventHotKeyID()
                GetEventParameter(eventRef!, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
                
                if let manager = ShortcutManager.registeredManagers[hotkeyID.id] {
                    DispatchQueue.main.async {
                        manager.action()
                    }
                }
                
                return noErr
            },
            1,
            &eventType,
            nil,
            &sharedEventHandler
        )
    }
    
    private func registerShortcut() {
        let hotKeyIDStruct = EventHotKeyID(signature: OSType(0x4B534854), id: hotKeyID)
        
        // Install the shared event handler only once for all instances
        ShortcutManager.installSharedEventHandlerIfNeeded()
        
        // Register the hotkey
        let modifiers = UInt32(keyCombo.modifiers.carbonFlags)
        let keyCode = UInt32(keyCombo.key)
        
        let registerResult = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyIDStruct,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerResult != noErr {
            registrationError = registerResult
            print("Failed to register hotkey: \(registerResult)")
        } else {
            registrationError = nil
        }
    }
    
    func unregisterShortcut() {
        // Unregister the hot key
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
} 
