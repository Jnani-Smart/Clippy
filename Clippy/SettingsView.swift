import SwiftUI

// First, define a global constant outside the view struct
private let defaultModifierValue: UInt = UInt(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)

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
    
    var body: some View {
        VStack {
            TabView(selection: $selectedTab) {
                generalSettingsView
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                    .tag(0)
                
                privacySettingsView
                    .tabItem {
                        Label("Privacy", systemImage: "lock")
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
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Done") {
                    isPresented = false
                    // Force dismiss the sheet
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
                .padding(.trailing)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 450, height: 350)
        .padding(.top)
        .onAppear {
            // Load from UserDefaults manually
            if let savedModifiers = UserDefaults.standard.object(forKey: "clipboardShortcutModifiers") as? UInt {
                shortcutModifiers = savedModifiers
            } else {
                // Use default value
                shortcutModifiers = UInt(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
                // Save default to UserDefaults
                UserDefaults.standard.set(shortcutModifiers, forKey: "clipboardShortcutModifiers")
            }
            
            currentKeyCombo = KeyCombo(key: shortcutKey, modifiers: NSEvent.ModifierFlags(rawValue: shortcutModifiers))
        }
    }
    
    // Move general settings to their own view
    private var generalSettingsView: some View {
        Form {
            Toggle("Start at login", isOn: $startAtLogin)
            
            Divider()
            
            Toggle("Hide menu bar icon", isOn: $hideMenuBarIcon)
                .help("When enabled, the menu bar icon will be hidden, but the app will still run in the background. You can still access the app using the keyboard shortcut.")
            
            Toggle("Hide dock icon", isOn: $hideDockIcon)
                .help("When enabled, the app won't appear in the dock. You can still access it via the menu bar icon or keyboard shortcut.")
                .onChange(of: hideDockIcon) { newValue in
                    // Notify app delegate to update dock icon visibility
                    NotificationCenter.default.post(
                        name: Notification.Name("UpdateDockIconVisibility"),
                        object: nil,
                        userInfo: ["hideDockIcon": newValue]
                    )
                }
            
            Divider()
            
            Picker("Maximum history items:", selection: $maxHistoryItems) {
                Text("20").tag(20)
                Text("30").tag(30)
                Text("50").tag(50)
                Text("100").tag(100)
            }
            
            Divider()
            
            Toggle("Auto-paste after copying", isOn: $autoPaste)
            
            Toggle("Store images in history", isOn: $storeImages)
            
            Divider()
            
            Toggle("Auto-delete old clipboard items", isOn: $enableAutoDelete)
                .help("Automatically delete clipboard items after the specified time period.")
            
            if enableAutoDelete {
                Picker("Delete after:", selection: $autoDeleteDuration) {
                    Text("1 hour").tag(3600)
                    Text("3 hours").tag(10800)
                    Text("12 hours").tag(43200)
                    Text("1 day").tag(86400)
                    Text("3 days").tag(259200)
                    Text("1 week").tag(604800)
                }
                .padding(.leading)
                .onChange(of: autoDeleteDuration) { _ in
                    // Notify ClipboardManager to update auto-delete timer
                    NotificationCenter.default.post(
                        name: Notification.Name("UpdateAutoDeleteSettings"),
                        object: nil
                    )
                }
            }
        }
        .padding()
    }
    
    // Privacy settings
    private var privacySettingsView: some View {
        Form {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Detect sensitive content (credit cards, emails, etc.)", isOn: $detectSensitiveContent)
                
                Toggle("Skip storing sensitive content", isOn: $skipSensitiveContent)
                    .disabled(!detectSensitiveContent)
                    .padding(.leading)
                
                Divider()
                
                Text("Your clipboard data is stored locally on your Mac and is never sent to any server.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Clear All History") {
                    if let appDelegate = NSApplication.shared.delegate as? ClipboardAppDelegate {
                        appDelegate.clipboardManager?.clearHistory()
                    }
                }
                .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    // Category settings
    private var categorySettingsView: some View {
        Form {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable automatic categories", isOn: $enableCategories)
                
                Text("When enabled, clipboard items will be automatically categorized based on content.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Text("Default Categories:")
                    .font(.headline)
                
                VStack(alignment: .leading) {
                    CategoryRow(name: "Code", icon: "chevron.left.forwardslash.chevron.right", color: .blue)
                    CategoryRow(name: "URLs", icon: "link", color: .green)
                    CategoryRow(name: "Images", icon: "photo", color: .orange)
                    CategoryRow(name: "Text", icon: "doc.text", color: .secondary)
                }
            }
        }
        .padding()
    }
    
    // Keyboard shortcut settings
    private var shortcutSettingsView: some View {
        Form {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Show clipboard history:")
                    Spacer()
                    if #available(macOS 14.0, *) {
                        ShortcutRecorder(keyCombo: $currentKeyCombo)
                            .onChange(of: currentKeyCombo) { oldValue, newValue in
                                if let combo = newValue {
                                    shortcutKey = combo.key
                                    shortcutModifiers = combo.modifiers.rawValue
                                    UserDefaults.standard.set(shortcutModifiers, forKey: "clipboardShortcutModifiers")
                                    
                                    // Notify the app to update shortcuts
                                    NotificationCenter.default.post(
                                        name: Notification.Name("UpdateShortcuts"),
                                        object: nil,
                                        userInfo: ["keyCombo": combo]
                                    )
                                }
                            }
                    } else {
                        ShortcutRecorder(keyCombo: $currentKeyCombo)
                            .onChange(of: currentKeyCombo) { newValue in
                                if let combo = newValue {
                                    shortcutKey = combo.key
                                    shortcutModifiers = combo.modifiers.rawValue
                                    UserDefaults.standard.set(shortcutModifiers, forKey: "clipboardShortcutModifiers")
                                    
                                    // Notify the app to update shortcuts
                                    NotificationCenter.default.post(
                                        name: Notification.Name("UpdateShortcuts"),
                                        object: nil,
                                        userInfo: ["keyCombo": combo]
                                    )
                                }
                            }
                    }
                }
                
                Divider()
                
                Text("Changes will take effect after restarting the app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// Helper view for category rows
struct CategoryRow: View {
    let name: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(name)
            
            Spacer()
            
            Image(systemName: "checkmark")
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}