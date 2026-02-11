import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    @Binding var showCategoryBar: Bool
    @Binding var selectedCategory: ClipboardCategory?
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
                .onChange(of: text) {
                    NotificationCenter.default.post(name: NSNotification.Name("SearchTextChanged"), object: nil)
                }
                .onSubmit {
                    NotificationCenter.default.post(name: NSNotification.Name("SearchTextChanged"), object: nil)
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    NotificationCenter.default.post(name: NSNotification.Name("SearchTextChanged"), object: nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .imageScale(.medium)
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.trailing, 4)
            }
            
            // Category filter toggle button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showCategoryBar.toggle()
                    if !showCategoryBar {
                        selectedCategory = nil
                    }
                }
            }) {
                Image(systemName: showCategoryBar ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(showCategoryBar ? .accentColor : .secondary)
                    .padding(.trailing, 8)
                    .imageScale(.medium)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Toggle Category Filter")
        }
        .modifier(GlassCardModifier(cornerRadius: 12))
    }
}

// MARK: - Reusable Liquid Glass modifier with fallback

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.thickMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.25), lineWidth: 0.5)
                )
        }
    }
}

struct GlassInteractiveModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.thickMaterial)
                        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.25), lineWidth: 0.5)
                )
        }
    }
}

struct GlassCapsuleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(
                    Capsule()
                        .fill(.thickMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.25), lineWidth: 0.5)
                )
        }
    }
}

// Glass modifier for clipboard item cards with hover state
struct GlassItemModifier: ViewModifier {
    var isHovered: Bool
    var cornerRadius: CGFloat = 12
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background {
                    if isHovered {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.accentColor.opacity(0.12))
                    }
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.thickMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.white.opacity(colorScheme == .dark ? 0.06 : 0.3))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            isHovered
                            ? Color.accentColor.opacity(0.5)
                            : Color.white.opacity(colorScheme == .dark ? 0.15 : 0.35),
                            lineWidth: 0.5
                        )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                    radius: isHovered ? 6 : 3,
                    x: 0,
                    y: isHovered ? 2 : 1
                )
        }
    }
}