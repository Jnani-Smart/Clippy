import SwiftUI
import Carbon

struct ShortcutRecorder: View {
    @Binding var keyCombo: KeyCombo?
    @State private var isRecording = false
    @State private var tempKeyCombo: KeyCombo?
    
    var body: some View {
        HStack(spacing: 8) {
            if let combo = keyCombo {
                Text(combo.displayString)
                    .frame(minWidth: 100)
                    .padding(6)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            } else {
                Text("None")
                    .frame(minWidth: 100)
                    .padding(6)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                if isRecording {
                    // Cancel recording
                    isRecording = false
                    tempKeyCombo = nil
                } else {
                    // Start recording
                    isRecording = true
                    tempKeyCombo = nil
                }
            }) {
                // Use SF Symbols that match macOS UI style
                Image(systemName: isRecording ? "xmark.circle" : "record.circle")
                    .font(.system(size: 14))
                    .foregroundColor(isRecording ? .red : .accentColor)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            .help(isRecording ? "Cancel recording" : "Record shortcut")
            
            if isRecording {
                Text("Press keys...")
                    .foregroundColor(.secondary)
                    .onAppear {
                        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                            handleKeyDown(event)
                            return nil
                        }
                    }
                    .onDisappear {
                        NSEvent.removeMonitor(self)
                    }
            }
            
            if keyCombo != nil {
                Button(action: {
                    // Instead of nil, set to default Cmd+Shift+V
                    let defaultModifiers = NSEvent.ModifierFlags([.command, .shift])
                    keyCombo = KeyCombo(key: 9, modifiers: defaultModifiers) // 9 is keycode for "V"
                }) {
                    // Use SF Symbol matching macOS reset/default symbol
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Reset to default (⌘⇧V)")
            }
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        guard isRecording else { return }
        
        // Skip recording if it's just a modifier key press
        if event.keyCode == 0 && (event.modifierFlags.contains(.command) || 
                                 event.modifierFlags.contains(.option) || 
                                 event.modifierFlags.contains(.control) || 
                                 event.modifierFlags.contains(.shift)) {
            return
        }
        
        // Prevent invalid key combinations - require at least one modifier
        let hasModifier = event.modifierFlags.contains(.command) || 
                         event.modifierFlags.contains(.option) || 
                         event.modifierFlags.contains(.control) || 
                         event.modifierFlags.contains(.shift)
        
        if !hasModifier {
            // Don't allow key without modifier
            return
        }
        
        // Create key combo from event
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let newCombo = KeyCombo(key: Int(event.keyCode), modifiers: modifiers)
        
        // Update bindings
        self.keyCombo = newCombo
        self.isRecording = false
        
        // Ensure the notification is posted
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: Notification.Name("UpdateShortcuts"),
                object: nil,
                userInfo: ["keyCombo": newCombo]
            )
        }
    }
}

// Add extension for displaying key combos nicely
extension KeyCombo {
    var displayString: String {
        var result = ""
        
        if modifiers.contains(.control) {
            result += "⌃"
        }
        if modifiers.contains(.option) {
            result += "⌥"
        }
        if modifiers.contains(.shift) {
            result += "⇧"
        }
        if modifiers.contains(.command) {
            result += "⌘"
        }
        
        // Convert key code to character
        let keyChar = keyCodeToChar(key)
        result += keyChar
        
        return result
    }
    
    private func keyCodeToChar(_ keyCode: Int) -> String {
        // Basic mapping of common keys
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        // Add more as needed
        default: return "[\(keyCode)]"
        }
    }
}