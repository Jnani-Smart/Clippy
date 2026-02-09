import SwiftUI

/// A view displaying the paste queue with items in FIFO order
/// Features native macOS liquid glass design and drag-to-reorder functionality
struct PasteQueueView: View {
    @ObservedObject var pasteQueueManager: PasteQueueManager
    @ObservedObject var clipboardManager: ClipboardManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredItemId: UUID? = nil
    @State private var draggingItem: ClipboardItem? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Queue header with liquid glass styling
            queueHeader
            
            // Subtle separator
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            // Queue content
            if pasteQueueManager.queueItems.isEmpty {
                emptyQueueView
            } else {
                queueListView
            }
            
            // Queue footer with actions
            queueFooter
        }
        .background(
            // Liquid glass background
            ZStack {
                // Base glass layer
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                
                // Gradient overlay for depth
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(colorScheme == .dark ? 0.08 : 0.05),
                                Color.clear,
                                Color.orange.opacity(colorScheme == .dark ? 0.04 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Inner highlight for glass effect
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.2 : 0.4),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .overlay(
            // Outer glow border
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    Color.orange.opacity(colorScheme == .dark ? 0.25 : 0.15),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color.orange.opacity(0.1), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Header
    
    private var queueHeader: some View {
        HStack(spacing: 12) {
            // Queue icon with animated badge
            ZStack(alignment: .topTrailing) {
                // Glass icon background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.orange.opacity(0.5),
                                        Color.orange.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.orange.opacity(0.2), radius: 8, x: 0, y: 4)
                
                Image(systemName: "list.number")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Animated count badge
                if pasteQueueManager.itemCount > 0 {
                    Text("\(pasteQueueManager.itemCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .orange.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .orange.opacity(0.4), radius: 4, x: 0, y: 2)
                        )
                        .offset(x: 10, y: -8)
                        .scaleEffect(pasteQueueManager.justQueued ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pasteQueueManager.justQueued)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Paste Queue")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(pasteQueueManager.itemCount == 0 
                     ? "Press ⌘C to add items" 
                     : "\(pasteQueueManager.itemCount) item\(pasteQueueManager.itemCount == 1 ? "" : "s") • Drag to reorder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator with glass styling
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    pasteQueueManager.toggleQueueMode()
                }
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(pasteQueueManager.isQueueModeActive 
                              ? Color.green 
                              : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .shadow(color: pasteQueueManager.isQueueModeActive 
                                ? Color.green.opacity(0.5) 
                                : Color.clear, 
                                radius: 4)
                    
                    Text(pasteQueueManager.isQueueModeActive ? "Active" : "Inactive")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(pasteQueueManager.isQueueModeActive ? .green : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    pasteQueueManager.isQueueModeActive 
                                    ? Color.green.opacity(0.3) 
                                    : Color.secondary.opacity(0.2),
                                    lineWidth: 0.5
                                )
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    // MARK: - Empty State
    
    private var emptyQueueView: some View {
        VStack(spacing: 12) {
            // Animated empty tray with glass effect
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: "tray")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.secondary, .secondary.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 4) {
                Text("Queue is empty")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Copy items with ⌘C while\nQueue Mode is active")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Queue List with Native Drag Reorder
    
    private var queueListView: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(Array(pasteQueueManager.queueItems.enumerated()), id: \.element.id) { index, item in
                    queueItemRow(item: item, index: index)
                        .onDrag {
                            self.draggingItem = item
                            return NSItemProvider(object: item.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: QueueDropDelegate(
                            item: item,
                            items: $pasteQueueManager.queueItems,
                            draggingItem: $draggingItem
                        ))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: pasteQueueManager.queueItems.map { $0.id })
        }
        .frame(maxHeight: 220)
    }
    
    // MARK: - Queue Item Row with Liquid Glass
    
    private func queueItemRow(item: ClipboardItem, index: Int) -> some View {
        HStack(spacing: 10) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
                .frame(width: 20)
            
            // Position indicator with glass effect
            ZStack {
                Circle()
                    .fill(
                        index == 0 
                        ? LinearGradient(
                            colors: [.orange, .orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1),
                                Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                index == 0 
                                ? Color.orange.opacity(0.5) 
                                : Color.primary.opacity(0.1),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: index == 0 ? Color.orange.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                
                if index == 0 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                }
            }
            
            // Item content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    itemTypeIcon(for: item)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(itemTypeColor(for: item))
                    
                    Text(item.preview)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.primary)
                }
                
                if let sourceApp = item.sourceApp {
                    Text(sourceApp)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Remove button on hover with glass effect
            if hoveredItemId == item.id {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        pasteQueueManager.removeFromQueue(item)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.secondary, .secondary.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            // Liquid glass item background
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        index == 0 
                        ? Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.08)
                        : (hoveredItemId == item.id 
                           ? Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04)
                           : Color.clear)
                    )
                
                // Glass highlight
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                index == 0 ? Color.orange.opacity(0.4) : Color.white.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .shadow(
            color: index == 0 ? Color.orange.opacity(0.15) : Color.black.opacity(0.05),
            radius: index == 0 ? 8 : 4,
            x: 0,
            y: index == 0 ? 4 : 2
        )
        .scaleEffect(draggingItem?.id == item.id ? 1.02 : 1.0)
        .opacity(draggingItem?.id == item.id ? 0.8 : 1.0)
        .contentShape(Rectangle())
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredItemId = isHovered ? item.id : nil
            }
        }
    }
    
    // MARK: - Footer with Liquid Glass Buttons
    
    private var queueFooter: some View {
        VStack(spacing: 0) {
            // Subtle separator
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            HStack(spacing: 12) {
                // Clear queue button with glass effect
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        pasteQueueManager.clearQueue()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                        Text("Clear")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(pasteQueueManager.queueItems.isEmpty)
                .opacity(pasteQueueManager.queueItems.isEmpty ? 0.5 : 1)
                
                Spacer()
                
                // Paste Next button with prominent glass styling
                Button(action: {
                    pasteQueueManager.pasteNext()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Paste Next")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        
                        // Keyboard shortcut hint
                        Text("⌃V")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                pasteQueueManager.queueItems.isEmpty 
                                ? LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.orange, .orange.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                            .shadow(
                                color: pasteQueueManager.queueItems.isEmpty ? .clear : .orange.opacity(0.4),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(pasteQueueManager.queueItems.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Helpers
    
    private func itemTypeIcon(for item: ClipboardItem) -> Image {
        switch item.type {
        case .text:
            if item.detectedLanguage != nil {
                return Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
            return Image(systemName: "doc.text")
        case .image:
            return Image(systemName: "photo")
        case .url:
            return Image(systemName: "link")
        }
    }
    
    private func itemTypeColor(for item: ClipboardItem) -> Color {
        switch item.type {
        case .text:
            if let language = item.detectedLanguage {
                return language.color
            }
            return .secondary
        case .image:
            return .orange
        case .url:
            return .green
        }
    }
}

// MARK: - Drop Delegate for Native Drag Reorder

struct QueueDropDelegate: DropDelegate {
    let item: ClipboardItem
    @Binding var items: [ClipboardItem]
    @Binding var draggingItem: ClipboardItem?
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggingItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - Queue Badge View (for showing on items in main list)

struct QueueBadge: View {
    let position: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .orange.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .orange.opacity(0.4), radius: 4, x: 0, y: 2)
            
            if position == 1 {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(position)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Compact Queue Indicator (for status bar)

struct CompactQueueIndicator: View {
    @ObservedObject var pasteQueueManager: PasteQueueManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "list.number")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .orange.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Text("\(pasteQueueManager.itemCount)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.orange.opacity(0.1), radius: 4, x: 0, y: 2)
        .opacity(pasteQueueManager.itemCount > 0 ? 1 : 0)
        .scaleEffect(pasteQueueManager.justQueued ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pasteQueueManager.justQueued)
        .animation(.easeInOut(duration: 0.2), value: pasteQueueManager.itemCount)
    }
}

// MARK: - Preview

struct PasteQueueView_Previews: PreviewProvider {
    static var previews: some View {
        PasteQueueView(
            pasteQueueManager: PasteQueueManager.shared,
            clipboardManager: ClipboardManager()
        )
        .frame(width: 320, height: 380)
        .padding()
    }
}
