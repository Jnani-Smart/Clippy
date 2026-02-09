import SwiftUI

/// A minimal view displaying the paste queue items
/// Consistent with Recent and Pinned section styling
struct PasteQueueView: View {
    @ObservedObject var pasteQueueManager: PasteQueueManager
    @ObservedObject var clipboardManager: ClipboardManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredItemId: UUID? = nil
    @State private var draggingItem: ClipboardItem? = nil
    
    var body: some View {
        Group {
            if pasteQueueManager.queueItems.isEmpty {
                emptyQueueView
            } else {
                queueListView
            }
        }
    }
    
    // MARK: - Empty State (consistent with other sections)
    
    private var emptyQueueView: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.number")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.orange.opacity(0.8))
                .imageScale(.large)
                .padding(.bottom, 1)
            
            Text("Queue is empty")
                .font(.headline)
            
            Text("Press ⌃C to activate, then ⌘C to add items")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(pasteQueueManager.isQueueModeActive ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                
                Text(pasteQueueManager.isQueueModeActive ? "Queue Mode Active" : "Queue Mode Inactive")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(pasteQueueManager.isQueueModeActive ? .green : .secondary)
            }
            .padding(.top, 8)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Queue List with Drag Reorder
    
    private var queueListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(pasteQueueManager.queueItems.enumerated()), id: \.element.id) { index, item in
                    queueItemRow(item: item, index: index)
                        .opacity(draggingItem?.id == item.id ? 0.3 : 1.0)
                        .blur(radius: draggingItem?.id == item.id ? 2 : 0)
                        .onDrag {
                            withAnimation(.easeOut(duration: 0.15)) {
                                self.draggingItem = item
                            }
                            
                            // Create a proper drag item with the text preview
                            let itemProvider = NSItemProvider()
                            itemProvider.registerDataRepresentation(forTypeIdentifier: "public.text", visibility: .all) { completion in
                                let data = item.preview.data(using: .utf8) ?? Data()
                                completion(data, nil)
                                return nil
                            }
                            return itemProvider
                        }
                        .onDrop(of: ["public.text"], delegate: QueueDropDelegate(
                            item: item,
                            items: $pasteQueueManager.queueItems,
                            draggingItem: $draggingItem
                        ))
                }
            }
            .padding(.top, 100) // Floating header + tab bar space
            .padding(.bottom, 55) // Floating footer pill space
            .padding(.horizontal, 8)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: pasteQueueManager.queueItems.map { $0.id })
    }
    
    // MARK: - Queue Item Row (consistent styling with ClipboardItemRow)
    
    private func queueItemRow(item: ClipboardItem, index: Int) -> some View {
        HStack(spacing: 8) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))
                .frame(width: 16)
            
            // Position badge
            ZStack {
                Circle()
                    .fill(
                        index == 0 
                        ? Color.orange 
                        : Color.secondary.opacity(colorScheme == .dark ? 0.3 : 0.2)
                    )
                    .frame(width: 22, height: 22)
                
                if index == 0 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                }
            }
            
            // Item type icon
            itemTypeIcon(for: item)
                .font(.system(size: 14))
                .foregroundColor(itemTypeColor(for: item))
                .frame(width: 20)
            
            // Item content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)
                
                if let sourceApp = item.sourceApp {
                    Text(sourceApp)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Remove button on hover
            if hoveredItemId == item.id {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        pasteQueueManager.removeFromQueue(item)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    index == 0
                    ? Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    : (hoveredItemId == item.id
                       ? Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04)
                       : Color.primary.opacity(colorScheme == .dark ? 0.04 : 0.02))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    index == 0 ? Color.orange.opacity(0.3) : Color.clear,
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredItemId = isHovered ? item.id : nil
            }
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
        withAnimation(.easeOut(duration: 0.2)) {
            draggingItem = nil
        }
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != item.id else {
            return
        }
        
        guard let fromIndex = items.firstIndex(where: { $0.id == draggingItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        
        // Perform smooth reordering with spring animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return true
    }
}

// MARK: - Queue Badge View (for showing on items in main list)

struct QueueBadge: View {
    let position: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange)
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
