import SwiftUI

/// A view displaying the paste queue with items in FIFO order
struct PasteQueueView: View {
    @ObservedObject var pasteQueueManager: PasteQueueManager
    @ObservedObject var clipboardManager: ClipboardManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredItemId: UUID? = nil
    @State private var draggedItem: ClipboardItem? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Queue header
            queueHeader
            
            Divider()
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
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    Color.orange.opacity(colorScheme == .dark ? 0.3 : 0.2),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Header
    
    private var queueHeader: some View {
        HStack {
            // Queue icon with badge
            ZStack(alignment: .topTrailing) {
                Image(systemName: "list.number")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                
                if pasteQueueManager.itemCount > 0 {
                    Text("\(pasteQueueManager.itemCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Circle().fill(Color.orange))
                        .offset(x: 8, y: -6)
                }
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Paste Queue")
                    .font(.system(size: 14, weight: .semibold))
                
                Text(pasteQueueManager.itemCount == 0 ? "Add items to queue" : "\(pasteQueueManager.itemCount) item\(pasteQueueManager.itemCount == 1 ? "" : "s") in queue")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Toggle button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    pasteQueueManager.toggleQueueMode()
                }
            }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(pasteQueueManager.isQueueModeActive ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(pasteQueueManager.isQueueModeActive ? "Active" : "Inactive")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(pasteQueueManager.isQueueModeActive ? .green : .secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(pasteQueueManager.isQueueModeActive ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
                )
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Empty State
    
    private var emptyQueueView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.secondary)
            
            Text("Queue is empty")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Right-click items and select\n\"Add to Paste Queue\"")
                .font(.system(size: 11))
                .foregroundColor(Color(.tertiaryLabelColor))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Queue List
    
    private var queueListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(pasteQueueManager.queueItems.enumerated()), id: \.element.id) { index, item in
                    queueItemRow(item: item, index: index)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                .onMove { source, destination in
                    pasteQueueManager.moveItems(from: source, to: destination)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pasteQueueManager.queueItems.map { $0.id })
        }
        .frame(maxHeight: 200)
    }
    
    // MARK: - Queue Item Row
    
    private func queueItemRow(item: ClipboardItem, index: Int) -> some View {
        HStack(spacing: 8) {
            // Position indicator
            ZStack {
                Circle()
                    .fill(index == 0 ? Color.orange : Color.secondary.opacity(0.2))
                    .frame(width: 24, height: 24)
                
                if index == 0 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
            
            // Item content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    itemTypeIcon(for: item)
                        .font(.system(size: 11))
                        .foregroundColor(itemTypeColor(for: item))
                    
                    Text(item.preview)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                if let sourceApp = item.sourceApp {
                    Text(sourceApp)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Remove button on hover
            if hoveredItemId == item.id {
                Button(action: {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        pasteQueueManager.removeFromQueue(item)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    index == 0 ?
                    Color.orange.opacity(colorScheme == .dark ? 0.15 : 0.1) :
                    (hoveredItemId == item.id ?
                     Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.05) :
                     Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    index == 0 ? Color.orange.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredItemId = isHovered ? item.id : nil
            }
        }
        .onDrag {
            draggedItem = item
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
    }
    
    // MARK: - Footer
    
    private var queueFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)
            
            HStack(spacing: 12) {
                // Clear queue button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        pasteQueueManager.clearQueue()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Clear")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(pasteQueueManager.queueItems.isEmpty)
                .opacity(pasteQueueManager.queueItems.isEmpty ? 0.5 : 1)
                
                Spacer()
                
                // Paste Next button
                Button(action: {
                    pasteQueueManager.pasteNext()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11))
                        Text("Paste Next")
                            .font(.system(size: 11, weight: .semibold))
                        
                        // Keyboard shortcut hint
                        Text("⌃V")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(pasteQueueManager.queueItems.isEmpty ? Color.gray : Color.orange)
                    )
                    .shadow(color: pasteQueueManager.queueItems.isEmpty ? .clear : .orange.opacity(0.3), radius: 4, y: 2)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(pasteQueueManager.queueItems.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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

// MARK: - Queue Badge View (for showing on items in main list)

struct QueueBadge: View {
    let position: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .orange.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 20, height: 20)
                .shadow(color: .orange.opacity(0.3), radius: 2, y: 1)
            
            if position == 1 {
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(position)")
                    .font(.system(size: 10, weight: .bold))
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
        HStack(spacing: 4) {
            Image(systemName: "list.number")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.orange)
            
            Text("\(pasteQueueManager.itemCount)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.15 : 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 0.5)
        )
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
        .frame(width: 300, height: 350)
        .padding()
    }
}
