import SwiftUI

// Remove our custom ProgrammingLanguage definition since the app already has CodeLanguage
// struct ProgrammingLanguage {
//     let displayName: String
//     let color: Color
// }

// Optimized ClipboardItemRow with better memory management
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isHovered: Bool
    let showFullContent: Bool
    @ObservedObject var clipboardManager: ClipboardManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        mainContent
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .background(backgroundShape)
            .overlay(borderShape)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.1),
                radius: isHovered ? 3 : 1,
                x: 0,
                y: isHovered ? 1 : 0
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .contextMenu {
                menuContent
            }
    }
    
    // Main content structure
    private var mainContent: some View {
        HStack(alignment: .top, spacing: 8) {
            // Icon column with simple styling
            getTypeIcon()
                .font(.system(size: 14))
                .foregroundColor(getIconColor())
                .frame(width: 18, height: 18)
                .padding(.top, 2)
            
            // Main content column
            VStack(alignment: .leading, spacing: 4) {
                contentPreview
                
                metadataRow
            }
        }
    }
    
    // Metadata row at the bottom
    private var metadataRow: some View {
        HStack(spacing: 10) {
            // Simple timestamp without icon
            Text(item.timestamp.timeAgo())
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Simple source app display without icon
            if let sourceApp = item.sourceApp {
                Text(sourceApp)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Pin button on hover only with reduced size
            if isHovered {
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        clipboardManager.togglePinStatus(item)
                    }
                }) {
                    Image(systemName: clipboardManager.isPinned(item) ? "pin.fill" : "pin")
                        .font(.system(size: 10))
                        .foregroundColor(clipboardManager.isPinned(item) ? .yellow : .secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
                .transition(.opacity)
            } else if clipboardManager.isPinned(item) {
                // Show pin indicator when not hovered but item is pinned
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
            }
        }
        .padding(.top, 2)
    }
    
    // Background shape
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                isHovered 
                ? Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.15)
                : Color(colorScheme == .dark ? .gray : .white).opacity(colorScheme == .dark ? 0.15 : 0.85)
            )
    }
    
    // Border shape
    private var borderShape: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                isHovered
                ? Color.accentColor.opacity(colorScheme == .dark ? 0.35 : 0.3)
                : Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.08),
                lineWidth: 0.5
            )
    }
    
    // VisionOS-inspired context menu
    private var menuContent: some View {
        Group {
            // Copy option
            Button {
                copyItemToClipboard()
            } label: {
                Text("Copy")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .padding(.vertical, 2)
            
            // Pin/Unpin option
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    clipboardManager.togglePinStatus(item)
                }
            } label: {
                Text(clipboardManager.isPinned(item) ? "Unpin" : "Pin")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .padding(.vertical, 2)
            
            Divider()
                .background(Color.secondary.opacity(0.1))
                .padding(.vertical, 4)
            
            // Type-specific options
            if case .url = item.type, let url = item.url {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Text("Open URL")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                .padding(.vertical, 2)
            }
            
            if case .image = item.type {
                // Standard save panel for image
                Button {
                    saveImage()
                } label: {
                    Text("Save Image")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                .padding(.vertical, 2)
            }
            
            Divider()
                .background(Color.secondary.opacity(0.1))
                .padding(.vertical, 4)
            
            // Delete option
            Button {
                withAnimation {
                    clipboardManager.deleteItem(item)
                }
            } label: {
                Text("Delete")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .padding(.vertical, 2)
        }
    }
    
    // Save image with standard save panel
    private func saveImage() {
        guard let imageData = item.imageData, let image = NSImage(data: imageData) else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["png", "jpg", "jpeg"]
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
    
    // Helper function to copy item back to clipboard
    private func copyItemToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            if let text = item.text {
                pasteboard.setString(text, forType: .string)
            }
        case .url:
            if let url = item.url?.absoluteString {
                pasteboard.setString(url, forType: .string)
            }
        case .image:
            if let imageData = item.imageData, let image = NSImage(data: imageData) {
                pasteboard.writeObjects([image as NSPasteboardWriting])
            }
        }
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
            // If it's code, show it differently
            if let language = item.detectedLanguage {
                codePreviewView(language: language)
            } else {
                // Regular text
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
    }
    
    // Code preview with language badge
    private func codePreviewView(language: CodeLanguage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Language badge matching icon color
            languageBadgeView(language: language)
            
            // Code snippet with proper formatting
            codeSnippetView(language: language)
        }
    }
    
    // Language badge component
    private func languageBadgeView(language: CodeLanguage) -> some View {
        HStack(spacing: 4) {
            Text(language.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(language.color.opacity(colorScheme == .dark ? 0.2 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            language.color.opacity(colorScheme == .dark ? 0.3 : 0.15),
                            lineWidth: 0.5
                        )
                )
        )
    }
    
    // Code snippet component
    @ViewBuilder
    private func codeSnippetView(language: CodeLanguage) -> some View {
        if #available(macOS 12.0, *), let formattedCode = item.formattedCode {
            // Handle either AttributedString or String
            if let formattedString = formattedCode as? String {
                codeTextView(text: formattedString)
            } else {
                // Fall back to regular text if it's AttributedString
                codeTextView(text: item.text ?? "")
            }
        } else {
            codeTextView(text: item.text ?? "")
        }
    }
    
    // Code text display
    private func codeTextView(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .lineLimit(showFullContent ? 15 : 3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.08),
                        lineWidth: 0.5
                    )
            )
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
        let iconColor: Color
        
        switch item.type {
        case .text:
            if let language = item.detectedLanguage {
                // Use language-specific icon and color if available
                iconName = "chevron.left.forwardslash.chevron.right"
                iconColor = language.color
            } else {
                iconName = "doc.text"
                iconColor = .secondary
            }
        case .image:
            iconName = "photo"
            iconColor = .orange
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
                iconColor = .green
            } else {
                iconName = "link"
                iconColor = .green
            }
        }
        
        return Image(systemName: iconName)
            .foregroundColor(iconColor)
    }
    
    // Helper function to get icon color (for backward compatibility)
    private func getIconColor() -> Color {
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
        // Use the image cache for better performance
        let imageId = String(describing: imageData.hashValue)
        
        if imageData.count < 10 * 1024 {
            // Small images load directly
            nsImage = NSImage(data: imageData)
        } else {
            // Larger images load asynchronously
            DispatchQueue.global(qos: .userInitiated).async {
                let image = ImageCache.shared.image(for: imageId, data: imageData)
                DispatchQueue.main.async {
                    self.nsImage = image
                }
            }
        }
    }
}
