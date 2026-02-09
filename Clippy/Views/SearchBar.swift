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
                    // Debug logging
                    print("Search text changed to: \(text)")
                    // This explicit notification of change helps update the search immediately
                    NotificationCenter.default.post(name: NSNotification.Name("SearchTextChanged"), object: nil)
                }
                // Submit handler to ensure search is triggered on Return key
                .onSubmit {
                    print("Search submitted with: \(text)")
                    NotificationCenter.default.post(name: NSNotification.Name("SearchTextChanged"), object: nil)
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    // Explicitly trigger search update when clearing text
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
                    
                    // If hiding the category bar, reset to "All" categories
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thickMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2), lineWidth: 0.5)
        )
    }
} 