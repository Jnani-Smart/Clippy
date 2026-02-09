import SwiftUI
import CoreGraphics
import Combine
import UniformTypeIdentifiers
import Quartz

// Enhanced visual effect view with modern styling
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        
        // Enhanced glass effect with modern styling
        view.wantsLayer = true
        view.layer?.cornerRadius = 28
        view.layer?.masksToBounds = true
        
        // Add subtle inner shadow for depth
        let innerShadow = NSShadow()
        innerShadow.shadowColor = NSColor.black.withAlphaComponent(0.1)
        innerShadow.shadowOffset = NSSize(width: 0, height: -1)
        innerShadow.shadowBlurRadius = 3
        view.shadow = innerShadow
        
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
    @EnvironmentObject var appDelegate: ClipboardAppDelegate
    @ObservedObject var pasteQueueManager = PasteQueueManager.shared
    @State private var searchText = ""
    @State private var hoveredItemId: UUID? = nil
    @State private var isClearing = false
    @State private var trashFilled = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var segmentedSelection = 0 // 0 = Recent, 1 = Pinned, 2 = Queue
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isSettingsOpening = false
    @State private var selectedCategory: ClipboardCategory? = nil
    @State private var caseSensitiveSearch = false
    @State private var showOnlyCode = false
    @State private var showCategoryBar = false
    @State private var isSelectMode = false
    @State private var selectedItems: Set<UUID> = []
    @State private var quickLookURL: URL? = nil
    @State private var showQuickLook = false
    @State private var keyEventMonitor: Any? = nil
    @State private var quickLookOpacity: Double = 0.0
    @State private var isQuickLookContentReady = false
    @State private var showClearAllConfirmation = false
    @State private var isClearButtonHovered = false
    @State private var trashAnimationPhase = 0
    
    // Add the timeAgo function right here, before it's used
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Helper function to determine trash button text
    private func getTrashButtonText() -> String {
        if isSelectMode {
            if !selectedItems.isEmpty {
                return "Delete"
            } else {
                return "Clear All"
            }
        } else {
            return "Clear"
        }
    }
    
    // Add caching for filtered items
    private var filteredItems: [ClipboardItem] {
        // Get the appropriate items based on the current tab
        let sourceItems: [ClipboardItem]
        switch segmentedSelection {
        case 0:
            sourceItems = clipboardManager.clipboardItems
        case 1:
            sourceItems = clipboardManager.pinnedItems
        case 2:
            sourceItems = pasteQueueManager.queueItems
        default:
            sourceItems = clipboardManager.clipboardItems
        }
        
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
        .sheet(isPresented: $showQuickLook) {
            if let url = quickLookURL {
                VStack(spacing: 0) {
                    // Custom header with close button
                    HStack {
                        Text("Quick Look")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            closeQuickLook()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    // Quick Look content with fallback
                    ZStack {
                        QuickLookView(url: url, isContentReady: $isQuickLookContentReady)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .opacity(quickLookOpacity)
                        
                        // Loading indicator while content is preparing
                        if !isQuickLookContentReady {
                            VStack {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .padding(.bottom, 8)
                                
                                Text("Loading preview...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Fallback message if Quick Look fails
                        VStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("Preview not available")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("File: \(url.lastPathComponent)")
                                .font(.caption)
                                .foregroundColor(Color(.tertiaryLabelColor))
                        }
                        .opacity(0) // Hidden by default, Quick Look will show content
                    }
                }
                .frame(minWidth: 700, minHeight: 500)
                .background(Color(NSColor.windowBackgroundColor))
                .onAppear {
                    // Reset content ready state
                    isQuickLookContentReady = false
                    quickLookOpacity = 0.0
                }
                .onChange(of: isQuickLookContentReady) { _, isReady in
                    if isReady {
                        // Smooth fade in animation once content is ready
                        withAnimation(.easeInOut(duration: 0.25)) {
                            quickLookOpacity = 1.0
                        }
                    }
                }
                .onKeyPress(.space) {
                    closeQuickLook()
                    return .handled
                }
                .onKeyPress(.escape) {
                    closeQuickLook()
                    return .handled
                }
            }
        }
        .onAppear {
            keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Spacebar: keyCode 49
                if event.keyCode == 49 {
                    if let hoveredId = hoveredItemId, let item = filteredItems.first(where: { $0.id == hoveredId }), canShowQuickLook(for: item) {
                        showQuickLook(for: item)
                        return nil // Consume event
                    }
                }
                // Escape: keyCode 53 (for select mode exit)
                if event.keyCode == 53 {
                    if isSelectMode {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSelectMode = false
                            selectedItems.removeAll()
                        }
                        return nil // Consume event
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = keyEventMonitor {
                NSEvent.removeMonitor(monitor)
                keyEventMonitor = nil
            }
        }
        // Monitor Queue Mode state changes reliably from the root view
        .onAppear {
            // Check initial state when window opens
            if pasteQueueManager.isQueueModeActive {
                segmentedSelection = 2
            }
        }
        .onChange(of: pasteQueueManager.isQueueModeActive) { isActive in
            if isActive {
                withAnimation {
                    segmentedSelection = 2 // Switch to Queue tab
                }
            } else {
                withAnimation {
                    segmentedSelection = 0 // Switch to Recent tab
                }
            }
        }
    }
    
    // Break view into smaller components for better performance
    private var mainContentView: some View {
        ZStack {
            // Content fills entire space, scrolls behind floating elements
            // Apply gradient mask to fade content at top and bottom edges
            Group {
                switch segmentedSelection {
                case 0:
                    contentView
                case 1:
                    pinnedItemsView
                case 2:
                    queueContentView
                default:
                    contentView
                }
            }
            .mask(
                VStack(spacing: 0) {
                    // Solid invisible zone - completely hides content behind header + search bar
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: isSelectMode ? 55 : 65)
                    
                    // Short gradient fade - content fades in just before segmented bar ends
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 35)
                    
                    // Fully visible area
                    Rectangle()
                        .fill(Color.black)
                    
                    // Bottom fade - hides content as it approaches footer
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 50)
                }
            )
            
            // Floating UI overlay
            VStack(spacing: 0) {
                // Floating header with blur
                floatingHeaderView
                
                // Floating segmented control (just below header divider)
                if !isSelectMode {
                    HStack(spacing: 1) {
                        tabButton(index: 0, icon: "clock.fill", label: "Recent")
                        tabButton(index: 1, icon: "pin.fill", label: "Pinned")
                        queueTabButton(index: 2, icon: "list.number", label: "Queue")
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thickMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: segmentedSelection)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)).animation(.easeOut(duration: 0.2)))
                }
                
                Spacer()
                
                // Floating Control+V pill for Queue tab
                if segmentedSelection == 2 && pasteQueueManager.itemCount > 0 {
                    Text("⌃V to paste next")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(.thickMaterial)
                                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 0.5)
                        )
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)))
                }
                
                // Floating footer with blur
                floatingFooterView
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: pasteQueueManager.itemCount > 0)
        }
        .clipped() // Ensure nothing renders outside bounds
        .frame(width: 320, height: 400)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelectMode)
        .alert("Clear All Items", isPresented: $showClearAllConfirmation) {
            Button("Cancel", role: .cancel) {
                // Do nothing, just dismiss
            }
            Button("Clear All", role: .destructive) {
                // Select all items and delete them
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    selectedItems = Set(filteredItems.map { $0.id })
                }
                // Auto-delete after a brief moment to show selection
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        deleteSelectedItems()
                    }
                }
            }
        } message: {
            Text("Permanently delete \(filteredItems.count) clipboard items? This action cannot be undone.")
        }
    }
    
    // Floating header with blur background
    private var floatingHeaderView: some View {
        VStack(spacing: 2) {
            ZStack {
                Text("Clippy")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .center)

                if isSelectMode {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSelectMode = false
                                selectedItems.removeAll()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(width: 12, height: 12)
                                Text("Cancel")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.thickMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            SearchBar(text: $searchText, showCategoryBar: $showCategoryBar, selectedCategory: $selectedCategory)
                .padding(.horizontal, 16)
                .padding(.bottom, 2)

            // Category filter bar with visibility control
            if showCategoryBar {
                categoryFilterBar
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelectMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showCategoryBar)
    }
    
    // Floating footer with blur background
    private var floatingFooterView: some View {
        HStack {
            // Dual-function trash button with hover and animation
            Button(action: {
                if segmentedSelection == 2 {
                    // Queue tab: animate trash and clear queue
                    triggerTrashAnimation()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            pasteQueueManager.clearQueue()
                        }
                    }
                } else if isSelectMode {
                    if !selectedItems.isEmpty {
                        // Delete selected items - animate trash
                        triggerTrashAnimation()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                deleteSelectedItems()
                            }
                        }
                    } else {
                        // Show confirmation alert for Clear All functionality
                        showClearAllConfirmation = true
                    }
                } else {
                    // Activate selection mode when not in selection mode with smooth transition
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isSelectMode = true
                    }
                }
            }) {
                HStack(spacing: 4) {
                    // Trash icon with skeuomorphic shake animation
                    Image(systemName: trashAnimationPhase > 0 ? "trash.fill" : "trash")
                        .font(.system(size: 12, weight: .medium))
                        .imageScale(.medium)
                        .foregroundColor(getClearButtonColor())
                        .rotationEffect(.degrees(trashAnimationPhase == 1 ? -15 : (trashAnimationPhase == 2 ? 15 : 0)))
                        .scaleEffect(trashAnimationPhase > 0 ? 1.2 : 1.0)
                    
                    Text(getTrashButtonText())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(getClearButtonColor())
                        .id("trash-button-text-\(getTrashButtonText())")
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.9)).animation(.easeOut(duration: 0.15)),
                            removal: .opacity.combined(with: .scale(scale: 1.1)).animation(.easeIn(duration: 0.1))
                        ))
                }
                .scaleEffect(isClearButtonHovered ? 1.05 : 1.0)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(segmentedSelection == 2 && pasteQueueManager.queueItems.isEmpty)
            .opacity(segmentedSelection == 2 && pasteQueueManager.queueItems.isEmpty ? 0.5 : 1)
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isClearButtonHovered = isHovered
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isClearButtonHovered)
            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: trashAnimationPhase)
            
            Spacer()
            
            // Settings button
            Button(action: {
                guard !isSettingsOpening else { return }
                isSettingsOpening = true
                appDelegate.openSettings()
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
            
            // Simple item count
            if segmentedSelection == 2 {
                Text("\(pasteQueueManager.itemCount) items")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else if isSelectMode {
                Text("\(selectedItems.count)/\(filteredItems.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Text("\(filteredItems.count) items")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thickMaterial)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var headerView: some View {
        VStack(spacing: 4) {
            ZStack {
                Text("Clippy")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .center)

                if isSelectMode {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSelectMode = false
                                selectedItems.removeAll()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(width: 12, height: 12)
                                Text("Cancel")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            SearchBar(text: $searchText, showCategoryBar: $showCategoryBar, selectedCategory: $selectedCategory)
                .padding(.horizontal, 16)
                .padding(.bottom, 0)

            // Removed selection bar; cancel button is now in the title row when in select mode

            // Category filter bar with visibility control
            if showCategoryBar {
                categoryFilterBar
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 2)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelectMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showCategoryBar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clippy")
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
            LazyVStack(spacing: isSelectMode ? 4 : 3) {
                ForEach(filteredItems) { item in
                    clipboardItemRow(for: item)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)),
                            removal: .opacity.combined(with: .scale(scale: 0.94, anchor: .center))
                        ))
                }
            }
            .padding(.top, isSelectMode ? 65 : 100) // Floating header + tab bar space
            .padding(.bottom, 55) // Floating footer pill space
            .padding(.horizontal, isSelectMode ? 0 : 8)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: filteredItems.map { $0.id })
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelectMode)
        }
    }
    
    private func clipboardItemRow(for item: ClipboardItem) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Selection indicator when in select mode
            if isSelectMode {
                Button(action: {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        if selectedItems.contains(item.id) {
                            selectedItems.remove(item.id)
                        } else {
                            selectedItems.insert(item.id)
                        }
                    }
                }) {
                    Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(selectedItems.contains(item.id) ? .accentColor : Color.secondary.opacity(0.6))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.leading, 12)
                .padding(.trailing, 10)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            
            ClipboardItemRow(
                item: item,
                isHovered: hoveredItemId == item.id,
                showFullContent: hoveredItemId == item.id,
                clipboardManager: clipboardManager
            )
            .overlay(alignment: .topTrailing) {
                // Queue position badge
                if let position = pasteQueueManager.positionInQueue(item) {
                    QueueBadge(position: position)
                        .offset(x: 6, y: -6)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .overlay(
                // Selection overlay when selected - refined styling
                selectedItems.contains(item.id) && isSelectMode ?
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.06))
                    )
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: selectedItems.contains(item.id))
                : nil
            )
            .padding(.trailing, isSelectMode ? 12 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pasteQueueManager.isInQueue(item))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectMode {
                // Handle selection in select mode
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    if selectedItems.contains(item.id) {
                        selectedItems.remove(item.id)
                    } else {
                        selectedItems.insert(item.id)
                    }
                }
            } else {
                // Normal tap behavior
                handleItemTap(item)
            }
        }
        .onHover { isHovered in
            if !isSelectMode {
                handleItemHover(isHovered: isHovered, item: item)
            }
        }
        .padding(.vertical, isSelectMode ? 2 : 1.5)
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
            
            // Type-specific options
            if case .url = item.type, let url = item.url {
                Button(action: {
                    NSWorkspace.shared.open(url)
                }) {
                    Label {
                        Text("Open URL")
                    } icon: {
                        Image(systemName: "link")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            
            if case .image = item.type {
                Button(action: {
                    saveImage(item)
                }) {
                    Label {
                        Text("Save Image")
                    } icon: {
                        Image(systemName: "square.and.arrow.down")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            
            // Quick Look option for supported types
            if canShowQuickLook(for: item) {
                Button(action: {
                    showQuickLook(for: item)
                }) {
                    Label {
                        Text("Quick Look")
                    } icon: {
                        Image(systemName: "eye")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            
            Divider()
            
            // Paste Queue options
            if pasteQueueManager.isInQueue(item) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        pasteQueueManager.removeFromQueue(item)
                    }
                }) {
                    Label {
                        HStack {
                            Text("Remove from Queue")
                            if let position = pasteQueueManager.positionInQueue(item) {
                                Text("(\(position))")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "minus.circle")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.orange)
                    }
                }
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        pasteQueueManager.addToQueue(item)
                    }
                }) {
                    Label {
                        Text("Add to Paste Queue")
                    } icon: {
                        Image(systemName: "list.number")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Divider()
            
            // Select option to enter selection mode
            if !isSelectMode {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSelectMode = true
                        selectedItems.insert(item.id)
                    }
                }) {
                    Label {
                        Text("Select")
                    } icon: {
                        Image(systemName: "checkmark.circle")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                
                Divider()
            }
            
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
                // Dual-function trash button with hover and animation
                Button(action: {
                    if segmentedSelection == 2 {
                        // Queue tab: animate trash and clear queue
                        triggerTrashAnimation()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                pasteQueueManager.clearQueue()
                            }
                        }
                    } else if isSelectMode {
                        if !selectedItems.isEmpty {
                            // Delete selected items - animate trash
                            triggerTrashAnimation()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    deleteSelectedItems()
                                }
                            }
                        } else {
                            // Show confirmation alert for Clear All functionality
                            showClearAllConfirmation = true
                        }
                    } else {
                        // Activate selection mode when not in selection mode with smooth transition
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isSelectMode = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        // Trash icon with skeuomorphic shake animation
                        Image(systemName: trashAnimationPhase > 0 ? "trash.fill" : "trash")
                            .font(.system(size: 12, weight: .medium))
                            .imageScale(.medium)
                            .foregroundColor(getClearButtonColor())
                            .rotationEffect(.degrees(trashAnimationPhase == 1 ? -15 : (trashAnimationPhase == 2 ? 15 : 0)))
                            .scaleEffect(trashAnimationPhase > 0 ? 1.2 : 1.0)
                        
                        Text(getTrashButtonText())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(getClearButtonColor())
                            .id("trash-button-text-\(getTrashButtonText())")
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.9)).animation(.easeOut(duration: 0.15)),
                                removal: .opacity.combined(with: .scale(scale: 1.1)).animation(.easeIn(duration: 0.1))
                            ))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(getClearButtonBackground())
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(getClearButtonBorder(), lineWidth: 1)
                    )
                    .scaleEffect(isClearButtonHovered ? 1.05 : 1.0)
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.horizontal)
                .disabled(segmentedSelection == 2 && pasteQueueManager.queueItems.isEmpty)
                .opacity(segmentedSelection == 2 && pasteQueueManager.queueItems.isEmpty ? 0.5 : 1)
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isClearButtonHovered = isHovered
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isClearButtonHovered)
                .animation(.spring(response: 0.15, dampingFraction: 0.5), value: trashAnimationPhase)
                
                Spacer()
                
                // Settings button
                Button(action: {
                    guard !isSettingsOpening else { return }
                    isSettingsOpening = true
                    appDelegate.openSettings()
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
                
                // Simple item count
                if segmentedSelection == 2 {
                    Text("\(pasteQueueManager.itemCount) items")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                } else if isSelectMode {
                    Text("\(selectedItems.count) of \(filteredItems.count) selected")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                } else {
                    Text("\(filteredItems.count) items")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal)
        }
    }
    
    // Helper for clear button color
    private func getClearButtonColor() -> Color {
        if isClearButtonHovered || trashAnimationPhase > 0 {
            return isSelectMode && selectedItems.isEmpty ? .red : .orange
        }
        return isSelectMode && selectedItems.isEmpty ? .red : .primary
    }
    
    // Helper for clear button background
    private func getClearButtonBackground() -> Color {
        if isClearButtonHovered || trashAnimationPhase > 0 {
            return isSelectMode && selectedItems.isEmpty ? Color.red.opacity(0.15) : Color.orange.opacity(0.12)
        }
        return isSelectMode && selectedItems.isEmpty ? Color.red.opacity(0.1) : Color.clear
    }
    
    // Helper for clear button border
    private func getClearButtonBorder() -> Color {
        if isClearButtonHovered || trashAnimationPhase > 0 {
            return isSelectMode && selectedItems.isEmpty ? Color.red.opacity(0.4) : Color.orange.opacity(0.3)
        }
        return isSelectMode && selectedItems.isEmpty ? Color.red.opacity(0.3) : Color.clear
    }
    
    // Skeuomorphic trash shake animation (iOS 6 style)
    private func triggerTrashAnimation() {
        trashAnimationPhase = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            trashAnimationPhase = 2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            trashAnimationPhase = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            trashAnimationPhase = 0
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
                    .padding(.top, 100) // Floating header + tab bar space
                    .padding(.bottom, 55) // Floating footer pill space
                    .padding(.horizontal, 8)
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
    
    // Helper method to create queue tab button with badge indicator
    private func queueTabButton(index: Int, icon: String, label: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                segmentedSelection = index
            }
        }) {
            HStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: segmentedSelection == index ? .semibold : .regular))
                        .imageScale(.medium)
                        .symbolEffect(.bounce.down, value: segmentedSelection == index)
                    
                    // Show badge with queue count if there are items
                    if pasteQueueManager.itemCount > 0 {
                        Text("\(pasteQueueManager.itemCount)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 12, minHeight: 12)
                            .background(Circle().fill(Color.orange))
                            .offset(x: 8, y: -6)
                    }
                }
                
                Text(label)
                    .font(.system(size: 12, weight: segmentedSelection == index ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(segmentedSelection == index ? 
                          (colorScheme == .dark ? Color.orange.opacity(0.2) : Color.orange.opacity(0.15)) : 
                          Color.clear)
                    .shadow(color: Color.black.opacity(segmentedSelection == index ? 0.06 : 0), radius: 1, x: 0, y: 1)
            )
            .contentShape(Rectangle())
            .foregroundColor(segmentedSelection == index ? .orange : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: segmentedSelection)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pasteQueueManager.itemCount)
    }
    
    // Paste Queue content view
    private var queueContentView: some View {
        PasteQueueView(
            pasteQueueManager: pasteQueueManager,
            clipboardManager: clipboardManager
        )
    }
    
    // Function to delete selected items using existing ClipboardManager methods
    private func deleteSelectedItems() {
        // Use the existing deleteItem method for each selected item
        let itemsToDelete = clipboardManager.clipboardItems.filter { selectedItems.contains($0.id) }
        let pinnedItemsToDelete = clipboardManager.pinnedItems.filter { selectedItems.contains($0.id) }
        
        // Delete each item using the existing method
        for item in itemsToDelete {
            clipboardManager.deleteItem(item)
        }
        
        for item in pinnedItemsToDelete {
            clipboardManager.deleteItem(item)
        }
        
        // Clear selection and exit select mode
        selectedItems.removeAll()
        isSelectMode = false
    }
    
    // MARK: - Quick Look functionality
    
    private func canShowQuickLook(for item: ClipboardItem) -> Bool {
        switch item.type {
        case .image:
            return item.imageData != nil
        case .url:
            return item.url != nil
        case .text:
            return item.text != nil && !item.text!.isEmpty
        }
    }
    
    private func showQuickLook(for item: ClipboardItem) {
        switch item.type {
        case .image:
            showQuickLookForImage(item)
        case .url:
            if let url = item.url {
                showQuickLookForURL(url)
            }
        case .text:
            if let filePath = extractFilePath(from: item.text) {
                showQuickLookForURL(URL(fileURLWithPath: filePath))
            } else {
                // For regular text, create a temporary text file to preview
                showQuickLookForText(item)
            }
        }
    }
    
    private func showQuickLookForImage(_ item: ClipboardItem) {
        guard let imageData = item.imageData else { return }
        
        // Create a temporary file for the image
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("quicklook_image_\(UUID().uuidString).png")
        
        do {
            try imageData.write(to: tempFile)
            quickLookURL = tempFile
            quickLookOpacity = 0.0 // Start hidden to prevent artifacts
            isQuickLookContentReady = false // Reset content ready state
            showQuickLook = true
        } catch {
            print("Error creating temporary file for Quick Look: \(error)")
        }
    }
    
    private func showQuickLookForURL(_ url: URL) {
        quickLookURL = url
        quickLookOpacity = 0.0 // Start hidden to prevent artifacts
        isQuickLookContentReady = false // Reset content ready state
        showQuickLook = true
    }
    
    private func closeQuickLook() {
        withAnimation(.easeInOut(duration: 0.2)) {
            quickLookOpacity = 0.0
        }
        
        // Close the sheet after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showQuickLook = false
            isQuickLookContentReady = false // Reset for next time
        }
    }
    
    private func showQuickLookForText(_ item: ClipboardItem) {
        guard let text = item.text else { return }
        
        // Create a temporary text file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("quicklook_text_\(UUID().uuidString).txt")
        
        do {
            try text.write(to: tempFile, atomically: true, encoding: .utf8)
            quickLookURL = tempFile
            quickLookOpacity = 0.0 // Start hidden to prevent artifacts
            isQuickLookContentReady = false // Reset content ready state
            showQuickLook = true
        } catch {
            print("Error creating temporary text file for Quick Look: \(error)")
        }
    }
    
    private func isPreviewableURL(_ url: URL) -> Bool {
        let previewableExtensions = ["pdf", "doc", "docx", "txt", "rtf", "jpg", "jpeg", "png", "gif", "mp4", "mov", "mp3", "wav"]
        return previewableExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func containsFilePath(_ text: String?) -> Bool {
        guard let text = text else { return false }
        
        // Check if the text looks like a file path
        let filePathPattern = #"^(/[^/\0]+)+/?$|^~/[^/\0]+(/[^/\0]+)*/?$|^[a-zA-Z]:\\.*$"#
        let regex = try? NSRegularExpression(pattern: filePathPattern, options: [])
        let range = NSRange(location: 0, length: text.count)
        
        if let match = regex?.firstMatch(in: text, options: [], range: range) {
            let filePath = String(text[Range(match.range, in: text)!])
            return FileManager.default.fileExists(atPath: filePath)
        }
        
        return false
    }
    
    private func extractFilePath(from text: String?) -> String? {
        guard let text = text, containsFilePath(text) else { return nil }
        
        // Extract the file path from text
        let filePathPattern = #"^(/[^/\0]+)+/?$|^~/[^/\0]+(/[^/\0]+)*/?$|^[a-zA-Z]:\\.*$"#
        let regex = try? NSRegularExpression(pattern: filePathPattern, options: [])
        let range = NSRange(location: 0, length: text.count)
        
        if let match = regex?.firstMatch(in: text, options: [], range: range) {
            let filePath = String(text[Range(match.range, in: text)!])
            
            // Expand tilde if present
            if filePath.hasPrefix("~/") {
                return NSString(string: filePath).expandingTildeInPath
            }
            
            return filePath
        }
        
        return nil
    }
    
    // Function to save image with standard save panel
    private func saveImage(_ item: ClipboardItem) {
        guard let imageData = item.imageData, let image = NSImage(data: imageData) else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "Clipboard_Image_\(Int(Date().timeIntervalSince1970)).png"
        savePanel.canCreateDirectories = true
        
        savePanel.beginSheetModal(for: NSApp.keyWindow!) { response in
            if response == .OK, let url = savePanel.url {
                do {
                    if let tiffData = image.tiffRepresentation, 
                       let rep = NSBitmapImageRep(data: tiffData), 
                       let pngData = rep.representation(using: .png, properties: [:]) {
                        try pngData.write(to: url)
                    }
                } catch {
                    print("Error saving image: \(error)")
                }
            }
        }
    }
}

// MARK: - Quick Look View
struct QuickLookView: NSViewRepresentable {
    let url: URL
    @Binding var isContentReady: Bool
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        let previewView = QLPreviewView()
        
        // Configure the preview view
        previewView.shouldCloseWithWindow = false
        previewView.autoresizingMask = [.width, .height]
        
        // Add the preview view to container
        containerView.addSubview(previewView)
        previewView.frame = containerView.bounds
        
        // Set the preview item after a brief delay to ensure proper initialization
        DispatchQueue.main.async {
            previewView.previewItem = url as QLPreviewItem
            
            // Mark content as ready after a short delay to allow QLPreviewView to initialize
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isContentReady = true
            }
        }
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let previewView = nsView.subviews.first as? QLPreviewView else { return }
        
        if previewView.previewItem?.previewItemURL != url {
            previewView.previewItem = url as QLPreviewItem
        }
        
        // Ensure proper frame
        previewView.frame = nsView.bounds
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
