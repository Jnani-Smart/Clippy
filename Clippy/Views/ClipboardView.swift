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
    @State private var selectedCategory: ClipboardCategory? = nil
    @State private var caseSensitiveSearch = false
    @State private var showOnlyCode = false
    @State private var showCategoryBar = false
    
    // Add the timeAgo function right here, before it's used
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Add caching for filtered items
    private var filteredItems: [ClipboardItem] {
        // Get the appropriate items based on the current tab
        let sourceItems = segmentedSelection == 0 ? clipboardManager.clipboardItems : clipboardManager.pinnedItems
        
        // Use the ClipboardManager's filter method for consistent filtering
        return clipboardManager.filterItems(
            category: selectedCategory,
            searchText: searchText,
            fromItems: sourceItems
        )
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
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.03)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.03)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            #endif
            
            #if targetEnvironment(macCatalyst)
            if let uiImage = UIImage(named: "background") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
            } else {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.03)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
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
            
            // Custom VisionOS-style segmented control
            HStack(spacing: 1) {
                tabButton(index: 0, icon: "clock.fill", label: "Recent")
                tabButton(index: 1, icon: "pin.fill", label: "Pinned")
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.04))
                    .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: segmentedSelection)
            
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
                .padding(.top, 3)
                .padding(.bottom, 3)
            
            SearchBar(text: $searchText, showCategoryBar: $showCategoryBar, selectedCategory: $selectedCategory)
                .padding(.horizontal, 14)
                .padding(.vertical, 3)
            
            // Category filter bar with visibility control
            if showCategoryBar {
                categoryFilterBar
                    .padding(.horizontal, 14)
                    .padding(.vertical, 3)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showCategoryBar)
            }
            
            Divider()
                .padding(.horizontal, 8)
                .padding(.top, showCategoryBar ? 0 : 3)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clipboard History")
    }
    
    // Category filter bar
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" category button
                categoryButton(nil, "All", "tray")
                
                // Category-specific buttons
                ForEach(ClipboardCategory.allCases, id: \.self) { category in
                    categoryButton(category, category.rawValue, category.iconName)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // Helper function to create a consistent category button
    private func categoryButton(_ category: ClipboardCategory?, _ title: String, _ iconName: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCategory = (selectedCategory == category) ? nil : category
            }
        }) {
            HStack(spacing: 3) {
                Image(systemName: iconName)
                    .font(.system(size: 11))
                    .foregroundColor(selectedCategory == category ? .white : (category?.color ?? .secondary))
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(selectedCategory == category ? .white : .primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedCategory == category ? Color.accentColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selectedCategory == category ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(BorderlessButtonStyle())
        .contentShape(Rectangle())
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selectedCategory)
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
        VStack(spacing: 8) {
            if let selectedCategory = selectedCategory {
                // Category-specific empty state
                Image(systemName: selectedCategory.iconName)
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(selectedCategory.color)
                    .imageScale(.large)
                    .padding(.bottom, 1)
                
                Text("No \(selectedCategory.rawValue) items")
                    .font(.headline)
                
                switch selectedCategory {
                case .text:
                    Text("Copy some text to see it here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                case .code:
                    Text("Copy code snippets to see them here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                case .url:
                    Text("Copy website links to see them here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                case .image:
                    Text("Copy images to see them here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                // Default empty state
                Image(systemName: "clipboard")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.secondary)
                    .imageScale(.large)
                    .padding(.bottom, 1)
                
                Text("No clipboard items")
                    .font(.headline)
                    
                Text("Copy some text or images to see them here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var clipboardItemsListView: some View {
        ScrollView {
            LazyVStack(spacing: 3) {
                ForEach(filteredItems) { item in
                    clipboardItemRow(for: item)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)),
                            removal: .opacity.combined(with: .scale(scale: 0.94, anchor: .center))
                        ))
                }
            }
            .padding(.top, 3)
            .padding(.bottom, 3)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: filteredItems.map { $0.id })
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
        .padding(.vertical, 1.5)
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
                // Clear button
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
                    HStack(spacing: 4) {
                        Image(systemName: trashFilled ? "trash.fill" : "trash")
                            .font(.system(size: 12, weight: .medium))
                            .imageScale(.medium)
                        
                        Text("Clear")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(trashFilled ? Color.red.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.horizontal)
                .disabled(isClearing)
                
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
                        .font(.system(size: 14, weight: .medium))
                        .imageScale(.medium)
                        .opacity(isSettingsOpening ? 0.7 : 1.0)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isSettingsOpening)
                
                // Display the count of filtered items, not just all items
                Text("\(filteredItems.count) items")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
            }
            .padding(.vertical, 6)
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
                VStack(spacing: 8) {
                    Image(systemName: "pin")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                        .padding(.bottom, 1)
                    Text("No pinned items")
                        .font(.headline)
                    Text("Pin items to keep them accessible")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredItems.isEmpty && !isClearing {
                // Reuse the empty state for filtered pinned items
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(filteredItems) { item in
                            clipboardItemRow(for: item)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)),
                                    removal: .opacity.combined(with: .scale(scale: 0.94, anchor: .center))
                                ))
                        }
                    }
                    .padding(.top, 3)
                    .padding(.bottom, 3)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: filteredItems.map { $0.id })
                }
            }
        }
    }
    
    // Helper method to create consistent tab buttons
    private func tabButton(index: Int, icon: String, label: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                segmentedSelection = index
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: segmentedSelection == index ? .semibold : .regular))
                    .imageScale(.medium)
                    .symbolEffect(.bounce.down, value: segmentedSelection == index)
                
                Text(label)
                    .font(.system(size: 12, weight: segmentedSelection == index ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(segmentedSelection == index ? 
                          (colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.85)) : 
                          Color.clear)
                    .shadow(color: Color.black.opacity(segmentedSelection == index ? 0.06 : 0), radius: 1, x: 0, y: 1)
            )
            .contentShape(Rectangle())
            .foregroundColor(segmentedSelection == index ? .primary : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: segmentedSelection)
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