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
    @State private var isPinHovered = false
    @State private var pinBounce = false
    
    var body: some View {
        mainContent
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .modifier(GlassItemModifier(isHovered: isHovered))
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onDrag {
                switch item.type {
                case .text:
                    if let text = item.text {
                        return NSItemProvider(object: text as NSString)
                    }
                case .url:
                    if let url = item.url {
                        return NSItemProvider(object: url as NSURL)
                    }
                case .image:
                    if let imageData = item.imageData, let image = NSImage(data: imageData) {
                        return NSItemProvider(object: image)
                    }
                }
                return NSItemProvider(object: item.preview as NSString)
            }
    }
    
    // Main content structure with consistent alignment
    private var mainContent: some View {
        HStack(alignment: .top, spacing: 8) {
            // Icon column with consistent positioning
            getTypeIcon()
                .font(.system(size: 14))
                .foregroundColor(getIconColor())
                .frame(width: 18, height: 18)
                .padding(.top, 2)
            
            // Main content column with consistent spacing
            VStack(alignment: .leading, spacing: 4) {
                contentPreview
                
                metadataRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Metadata row at the bottom with consistent alignment
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
                    // Trigger iOS-style bounce
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                        pinBounce = true
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        clipboardManager.togglePinStatus(item)
                    }
                    // Reset bounce
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                            pinBounce = false
                        }
                    }
                }) {
                    Image(systemName: clipboardManager.isPinned(item) ? "pin.fill" : "pin")
                        .font(.system(size: 10))
                        .foregroundColor(isPinHovered || clipboardManager.isPinned(item) ? .yellow : .secondary)
                        .scaleEffect(pinBounce ? 1.35 : (isPinHovered ? 1.15 : 1.0))
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPinHovered)
                        .animation(.spring(response: 0.25, dampingFraction: 0.4), value: pinBounce)
                }
                .buttonStyle(BorderlessButtonStyle())
                .onHover { hovering in
                    isPinHovered = hovering
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else if clipboardManager.isPinned(item) {
                // Show pin indicator when not hovered but item is pinned
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    

    
    // Save image with standard save panel
    private func saveImage() {
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
                // Regular text (slight reveal on hover for consistency)
                Text(item.preview)
                    .font(.system(size: 13))
                    .lineLimit(showFullContent ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
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
                .foregroundColor(language.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .modifier(GlassCardModifier(cornerRadius: 8))
    }
    
    // Code snippet component
    @ViewBuilder
    private func codeSnippetView(language: CodeLanguage) -> some View {
        if #available(macOS 12.0, *), let formattedCode = item.formattedCode {
            // Convert AttributedString to String for display
            let codeText = String(formattedCode.characters)
            codeTextView(text: codeText)
        } else {
            codeTextView(text: item.text ?? "")
        }
    }
    
    // Code text display
    private func codeTextView(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .lineLimit(showFullContent ? 6 : 3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .modifier(GlassCardModifier(cornerRadius: 8))
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
        
        // Add debugging for image loading
        #if DEBUG
        print("🖼️ LazyImageView loading image: \(imageData.count) bytes")
        #endif
        
        // Validate image data first
        guard !imageData.isEmpty else {
            #if DEBUG
            print("❌ LazyImageView: Image data is empty")
            #endif
            return
        }
        
        // Try to create NSImage directly first
        if let directImage = NSImage(data: imageData) {
            #if DEBUG
            print("✅ LazyImageView: Successfully created NSImage directly")
            #endif
            nsImage = directImage
            return
        }
        
        // Check if this might be SVG data
        if let svgString = String(data: imageData, encoding: .utf8), svgString.contains("<svg") {
            #if DEBUG
            print("🎨 LazyImageView: Detected SVG content, attempting to render")
            #endif
            
            // For SVG, create a placeholder image with SVG indicator
            let placeholderImage = createSVGPlaceholder()
            nsImage = placeholderImage
            return
        }
        
        #if DEBUG
        print("❌ LazyImageView: Failed to create NSImage from data")
        #endif
        
        // If direct creation fails, try using the cache (which might have better error handling)
        if imageData.count < 10 * 1024 {
            // Small images load directly - but we already tried that above
            #if DEBUG
            print("❌ LazyImageView: Small image failed to load")
            #endif
        } else {
            // Larger images load asynchronously
            DispatchQueue.global(qos: .userInitiated).async {
                let image = ImageCache.shared.image(for: imageId, data: imageData)
                DispatchQueue.main.async {
                    if image.size.width > 0 && image.size.height > 0 {
                        #if DEBUG
                        print("✅ LazyImageView: Successfully loaded large image via cache")
                        #endif
                        self.nsImage = image
                    } else {
                        #if DEBUG
                        print("❌ LazyImageView: Cache returned invalid image")
                        #endif
                    }
                }
            }
        }
    }
    
    private func createSVGPlaceholder() -> NSImage {
        let size = NSSize(width: 100, height: 60)
        let image = NSImage(size: size)
        
        image.lockFocus()
        defer { image.unlockFocus() }
        
        // Draw background
        NSColor.controlBackgroundColor.set()
        let rect = NSRect(origin: .zero, size: size)
        rect.fill()
        
        // Draw border
        NSColor.separatorColor.set()
        rect.frame()
        
        // Add SVG text
        let text = "SVG"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
        
        return image
    }
}
