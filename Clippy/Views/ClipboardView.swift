import SwiftUI
import CoreGraphics

// Re-add the VisualEffectView that was removed
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        
        // Make it similar to Finder's translucent effect
        view.wantsLayer = true
        view.layer?.cornerRadius = 0
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct ClipboardView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @State private var searchText = ""
    @State private var hoveredItemId: UUID? = nil
    @State private var isClearing = false
    @State private var trashFilled = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSettings = false
    @State private var segmentedSelection = 0 // 0 = Recent, 1 = Pinned
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isSettingsOpening = false
    
    // Add the timeAgo function right here, before it's used
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Add caching for filtered items
    private var filteredItems: [ClipboardItem] {
        guard !searchText.isEmpty else { 
            return clipboardManager.clipboardItems
        }
        
        return clipboardManager.clipboardItems.filter { item in
            if item.type == .text, let text = item.text {
                return text.localizedCaseInsensitiveContains(searchText)
            }
            return false
        }
    }
    
    // Use a more efficient body implementation
    var body: some View {
        ZStack {
            // More efficient background - use native material only when needed
            #if os(macOS)
            if #available(macOS 12.0, *) {
                Rectangle()
                    .fill(Material.ultraThinMaterial)
                    .edgesIgnoringSafeArea(.all)
            } else {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .edgesIgnoringSafeArea(.all)
            }
            #endif
            
            mainContentView
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
                .environmentObject(clipboardManager)
        }
        // Add keyboard shortcut to close with ESC key
        .keyboardShortcut(.cancelAction)
    }
    
    // Break view into smaller components for better performance
    private var mainContentView: some View {
        VStack(spacing: 0) {
            headerView
            
            // Add segmented control
            Picker("", selection: $segmentedSelection) {
                Text("Recent").tag(0)
                Text("Pinned").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Show either recent or pinned based on selection
            if segmentedSelection == 0 {
                contentView
            } else {
                pinnedItemsView
            }
            
            footerView
        }
        .frame(width: 320, height: 400)
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            Text("Clipboard History")
                .font(.headline)
                .padding(.top, 12)
            
            SearchBar(text: $searchText)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clipboard History")
    }
    
    private var contentView: some View {
        Group {
            if filteredItems.isEmpty && !isClearing {
                emptyStateView
            } else {
                clipboardItemsListView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary)
                .imageScale(.large)
            Text("No clipboard items")
                .font(.headline)
            Text("Copy some text or images to see them here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var clipboardItemsListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredItems) { item in
                    clipboardItemRow(for: item)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func clipboardItemRow(for item: ClipboardItem) -> some View {
        ClipboardItemRow(
            item: item,
            isHovered: hoveredItemId == item.id,
            showFullContent: hoveredItemId == item.id,
            clipboardManager: clipboardManager
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleItemTap(item)
        }
        .onHover { isHovered in
            handleItemHover(isHovered: isHovered, item: item)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .transition(.opacity)
        .modifier(MinimizeEffect(isActive: isClearing))
        .accessibilityLabel("\(item.preview), copied \(item.timestamp.timeAgo())")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to copy and paste this item")
        .contextMenu {
            Button(action: {
                clipboardManager.copyItemToPasteboard(item)
            }) {
                Label {
                    Text("Copy")
                } icon: {
                    Image(systemName: "doc.on.doc")
                        .symbolRenderingMode(.hierarchical)
                }
            }
            
            Button(action: {
                clipboardManager.togglePinStatus(item)
            }) {
                if clipboardManager.isPinned(item) {
                    Label {
                        Text("Unpin")
                    } icon: {
                        Image(systemName: "pin.slash")
                            .symbolRenderingMode(.hierarchical)
                    }
                } else {
                    Label {
                        Text("Pin")
                    } icon: {
                        Image(systemName: "pin")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                clipboardManager.deleteItem(item)
            }) {
                Label {
                    Text("Delete")
                } icon: {
                    Image(systemName: "trash")
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
    }
    
    private func handleItemTap(_ item: ClipboardItem) {
        clipboardManager.copyItemToPasteboard(item)
        
        // Auto-paste after copying
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            simulatePaste()
        }
        
        // Close the current window efficiently
        closeWindow()
    }
    
    private func handleItemHover(isHovered: Bool, item: ClipboardItem) {
        // Debounce hover events
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                hoveredItemId = isHovered ? item.id : nil
            }
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Button(action: {
                    // Guard against multiple clicks
                    guard !isClearing else { return }
                    
                    // Simplified animation
                    isClearing = true
                    trashFilled = true
                    
                    // Clear with minimal animations
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        clipboardManager.clearHistory()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isClearing = false
                            trashFilled = false
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: trashFilled ? "trash.fill" : "trash")
                            .font(.system(size: 13, weight: .medium))
                            .imageScale(.medium)
                            .foregroundColor(trashFilled ? .red : .primary)
                        
                        Text("Clear")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(trashFilled ? Color.red.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.horizontal)
                .disabled(isClearing)
                
                // Add export button
                Button(action: {
                    guard !isExporting else { return }
                    isExporting = true
                    exportHistory()
                    // Reset after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isExporting = false
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .imageScale(.medium)
                        .opacity(isExporting ? 0.7 : 1.0)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Export clipboard history")
                .disabled(isExporting)
                
                // Add import button
                Button(action: {
                    guard !isImporting else { return }
                    isImporting = true
                    importHistory()
                    // Reset after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isImporting = false
                    }
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                        .imageScale(.medium)
                        .opacity(isImporting ? 0.7 : 1.0)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Import clipboard history")
                .disabled(isImporting)
                
                Spacer()
                
                // Settings button
                Button(action: {
                    guard !isSettingsOpening else { return }
                    isSettingsOpening = true
                    showSettings = true
                    // Reset after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isSettingsOpening = false
                    }
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .medium))
                        .imageScale(.medium)
                        .opacity(isSettingsOpening ? 0.7 : 1.0)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isSettingsOpening)
                
                Text("\(clipboardManager.clipboardItems.count) items")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
        }
    }
    
    // More efficient window closing with fade-out animation
    private func closeWindow() {
        NSApplication.shared.hide(nil)
        
        // Find and animate window closing
        DispatchQueue.global(qos: .userInteractive).async {
            if let window = NSApplication.shared.windows.first(where: { $0.isVisible }) {
                DispatchQueue.main.async {
                    // Fade-out animation
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.2
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        window.animator().alphaValue = 0.0
                    }, completionHandler: {
                        window.close()
                    })
                }
            }
        }
    }
    
    // Optimized paste simulation
    private func simulatePaste() {
        DispatchQueue.global(qos: .userInteractive).async {
            let source = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            keyDown?.flags = .maskCommand
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }
    
    // Add export/import methods
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
    
    // The initializer should be public (implicitly) - make sure there's no private modifier
    // If you have an init method, ensure it doesn't have 'private' before it
    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
        // Any other initialization...
    }
    
    // Add pinnedItemsView
    private var pinnedItemsView: some View {
        Group {
            if clipboardManager.pinnedItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pin")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                    Text("No pinned items")
                        .font(.headline)
                    Text("Pin items to keep them accessible")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(clipboardManager.pinnedItems) { item in
                            clipboardItemRow(for: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// Optimized ClipboardItemRow with better memory management
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isHovered: Bool
    let showFullContent: Bool
    @ObservedObject var clipboardManager: ClipboardManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Icon column
            getTypeIcon()
                .font(.system(size: 14))
                .foregroundColor(getIconColor())
                .frame(width: 16, height: 16)
                .padding(.top, 2)
            
            // Main content column
            VStack(alignment: .leading, spacing: 5) {
                contentPreview
                
                HStack {
                    Text(item.timestamp.timeAgo())
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Pin button
                    if isHovered {
                        Button(action: { 
                            withAnimation {
                                clipboardManager.togglePinStatus(item)
                            }
                        }) {
                            Image(systemName: clipboardManager.isPinned(item) ? "pin.fill" : "pin")
                                .font(.system(size: 11))
                                .foregroundColor(clipboardManager.isPinned(item) ? .yellow : .secondary)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isHovered 
                    ? Color.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.15)
                    : Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.03)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isHovered 
                    ? Color.accentColor.opacity(0.5) 
                    : Color.primary.opacity(0.05),
                    lineWidth: 1
                )
        )
    }
    
    // Extract content preview for better organization
    @ViewBuilder
    private var contentPreview: some View {
        switch item.type {
        case .text:
            textPreview
        case .url:
            urlPreview
        case .image:
            imagePreview
        }
    }
    
    @ViewBuilder
    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.preview)
                .font(.system(size: 13))
                .lineLimit(showFullContent ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            
            if showFullContent, let text = item.text, text.count > 60 {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    @ViewBuilder
    private var urlPreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let url = item.url {
                Text(url.host ?? url.absoluteString)
                    .font(.system(size: 13, weight: .medium))
                
                if showFullContent {
                    Text(url.absoluteString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(item.preview)
                    .font(.system(size: 13))
            }
        }
    }
    
    @ViewBuilder
    private var imagePreview: some View {
        if let imageData = item.imageData {
            // Use LazyImage for better performance
            LazyImageView(imageData: imageData, isExpanded: showFullContent)
        }
    }
    
    // Helper function to get the appropriate icon
    private func getTypeIcon() -> some View {
        let iconName: String
        
        switch item.type {
        case .text:
            iconName = "doc.text"
        case .image:
            iconName = "photo"
        case .url:
            if let url = item.url?.absoluteString.lowercased() {
                if url.contains("youtube") || url.contains("vimeo") {
                    iconName = "play.rectangle"
                } else if url.contains("github") {
                    iconName = "chevron.left.forwardslash.chevron.right"
                } else if url.contains("twitter") || url.contains("x.com") {
                    iconName = "message"
                } else if url.contains("instagram") || url.contains("facebook") {
                    iconName = "person.circle"
                } else if url.contains("maps") || url.contains("location") {
                    iconName = "map"
                } else if url.contains("mail") || url.contains("gmail") {
                    iconName = "envelope"
                } else {
                    iconName = "link"
                }
            } else {
                iconName = "link"
            }
        }
        
        return Image(systemName: iconName)
    }
    
    // Helper function to get the icon color
    private func getIconColor() -> Color {
        switch item.type {
        case .text:
            return .secondary
        case .image:
            return Color.blue
        case .url:
            return Color.green
        }
    }
}

// Efficient image loading
struct LazyImageView: View {
    let imageData: Data
    let isExpanded: Bool
    @State private var nsImage: NSImage?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Image")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            
            if let image = nsImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: isExpanded ? 100 : 40)
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 40)
                    .cornerRadius(4)
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let image = NSImage(data: imageData)
            DispatchQueue.main.async {
                self.nsImage = image
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .imageScale(.medium)
            
            TextField("Search", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 7)
                .onTapGesture {
                    isEditing = true
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                        .imageScale(.medium)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
        )
    }
}

// Simplified minimalist effect modifier
struct MinimizeEffect: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 0.5 : 1.0, anchor: .bottom)
            .opacity(isActive ? 0 : 1)
    }
}

// Preview provider
struct ClipboardView_Previews: PreviewProvider {
    static var previews: some View {
        ClipboardView(clipboardManager: ClipboardManager())
            .frame(width: 320, height: 400)
    }
}

extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
} 