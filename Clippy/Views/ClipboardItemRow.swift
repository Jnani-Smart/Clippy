import SwiftUI

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
            // If it's code, show it differently
            if let language = item.detectedLanguage {
                VStack(alignment: .leading, spacing: 2) {
                    // Language badge
                    HStack(spacing: 4) {
                        // Language name only
                        Text(language.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(language.color)
                            .padding(.trailing, 4)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(language.color.opacity(0.1))
                    .cornerRadius(4)
                    
                    // Code snippet with proper formatting
                    if #available(macOS 12.0, *), let formattedCode = item.formattedCode {
                        Text(formattedCode)
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(showFullContent ? 15 : 3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.05))
                            )
                    } else {
                        Text(item.text ?? "")
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(showFullContent ? 15 : 3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.05))
                            )
                    }
                }
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
        DispatchQueue.global(qos: .userInitiated).async {
            let image = NSImage(data: imageData)
            DispatchQueue.main.async {
                self.nsImage = image
            }
        }
    }
} 