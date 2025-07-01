import AppKit

// Services integration for system-wide features
extension ClipboardAppDelegate: NSServicesMenuRequestor {
    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        if filename.hasSuffix(".json") {
            let url = URL(fileURLWithPath: filename)
            return clipboardManager?.importHistory(from: url) ?? false
        }
        return false
    }
    
    func service(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) -> Bool {
        if userData == "copyToClipboardHistory" {
            if let string = pasteboard.string(forType: .string) {
                clipboardManager?.addItem(string)
                return true
            }
        }
        return false
    }
} 

