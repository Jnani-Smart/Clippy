import Foundation
import SwiftUI

// Expand the CodeLanguage enum with more language options
enum CodeLanguage: String, Codable, CaseIterable {
    case swift
    case python
    case javascript
    case typescript
    case html
    case css
    case c
    case cpp
    case csharp
    case java
    case go
    case rust
    case ruby
    case php
    case sql
    case markdown
    case json
    case xml
    case yaml
    case bash
    case clike
    
    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .html: return "HTML"
        case .css: return "CSS"
        case .c: return "C"
        case .cpp: return "C++"
        case .csharp: return "C#"
        case .java: return "Java"
        case .go: return "Go"
        case .rust: return "Rust"
        case .ruby: return "Ruby"
        case .php: return "PHP"
        case .sql: return "SQL"
        case .markdown: return "Markdown"
        case .json: return "JSON"
        case .xml: return "XML"
        case .yaml: return "YAML"
        case .bash: return "Bash/Shell"
        case .clike: return "Code"
        }
    }
    
    var iconName: String {
        switch self {
        case .swift: return "swift"
        case .python: return "python"
        case .javascript, .typescript: return "js"
        case .html, .xml: return "html"
        case .css: return "css3"
        case .c, .cpp, .csharp: return "c"
        case .java: return "java"
        case .go: return "go"
        case .rust: return "rust"
        case .ruby: return "ruby"
        case .php: return "php"
        case .sql: return "database"
        case .markdown: return "markdown"
        case .json: return "braces"
        case .yaml: return "yaml"
        case .bash: return "terminal"
        case .clike: return "code"
        }
    }
    
    var color: Color {
        switch self {
        case .swift: return Color(red: 1.0, green: 0.5, blue: 0.0) // Brighter orange
        case .python: return Color(red: 0.0, green: 0.7, blue: 1.0) // Brighter blue
        case .javascript, .typescript: return Color(red: 0.95, green: 0.8, blue: 0.0) // Vibrant yellow
        case .html, .xml: return Color(red: 0.95, green: 0.2, blue: 0.2) // Bright red
        case .css: return Color(red: 0.2, green: 0.6, blue: 0.95) // Bright blue
        case .c: return Color(red: 0.1, green: 0.8, blue: 0.8) // Bright teal (new color for C)
        case .cpp: return Color(red: 0.7, green: 0.3, blue: 1.0) // Vibrant purple for C++
        case .csharp: return Color(red: 0.4, green: 0.65, blue: 1.0) // Brighter blue-purple for C#
        case .java: return Color(red: 0.95, green: 0.4, blue: 0.1) // Vibrant red-orange
        case .go: return Color(red: 0.1, green: 0.8, blue: 0.8) // Bright cyan
        case .rust: return Color(red: 0.95, green: 0.5, blue: 0.0) // Vibrant orange
        case .ruby: return Color(red: 0.95, green: 0.15, blue: 0.15) // Bright red
        case .php: return Color(red: 0.7, green: 0.3, blue: 0.9) // Bright purple
        case .sql: return Color(red: 0.2, green: 0.85, blue: 0.4) // Bright green
        case .markdown: return Color(red: 0.2, green: 0.6, blue: 0.95) // Bright blue
        case .json: return Color(red: 0.95, green: 0.75, blue: 0.1) // Bright gold
        case .yaml: return Color(red: 0.3, green: 0.85, blue: 0.5) // Bright green
        case .bash: return Color(red: 0.6, green: 0.6, blue: 0.6) // Medium gray
        case .clike: return Color(red: 0.6, green: 0.6, blue: 0.8) // Bluish gray
        }
    }
}

// Extend ClipboardItem to support code syntax detection
extension ClipboardItem {
    var detectedLanguage: CodeLanguage? {
        guard type == .text, let text = text else { return nil }
        
        // Early exit for very short snippets that likely aren't code
        if text.count < 3 {
            return nil
        }
        
        // Check for code indentation patterns
        let hasCodeIndentation = text.contains("\n    ") || text.contains("\n\t")
        let hasMultipleLines = text.components(separatedBy: "\n").count > 1
        
        // Common code syntax patterns
        let hasBraces = text.contains("{") && text.contains("}")
        let hasParentheses = text.contains("(") && text.contains(")")
        let hasSemicolons = text.contains(";")
        let hasEquals = text.contains(" = ")
        let hasComments = text.contains("//") || text.contains("/*") || text.contains("*/") || text.contains("#") 
        
        // Check for file extensions in the text (common in code discussions)
        if let fileExtension = extractFileExtension(from: text) {
            if let language = detectLanguageFromExtension(fileExtension) {
                return language
            }
        }
        
        // Early specific language checks with more reliable patterns
        
        // Swift specific checks
        if text.contains("import SwiftUI") || text.contains("import UIKit") ||
           (text.contains("func ") && text.contains("->")) ||
           text.contains("@State ") || text.contains("@ObservedObject") {
            return .swift
        }
        
        // Python specific checks
        if text.contains("def ") && text.contains(":") || 
           text.contains("import numpy") || text.contains("import pandas") ||
           text.contains("__init__") || text.contains("if __name__ == \"__main__\"") {
            return .python
        }
        
        // JavaScript/TypeScript checks
        if text.contains("const ") || text.contains("let ") {
            if text.contains(": ") && (text.contains("interface ") || text.contains("<T>")) {
                return .typescript
            }
            return .javascript
        }
        
        // HTML detection
        if (text.contains("<html") || text.contains("<!DOCTYPE html")) ||
           (text.contains("<div") && text.contains("</div>")) ||
           (text.contains("<p>") && text.contains("</p>")) {
            return .html
        }
        
        // CSS detection
        if text.contains("{") && (text.contains("px") || text.contains("em") || text.contains("rem")) &&
           (text.contains("color:") || text.contains("margin:") || text.contains("padding:")) {
            return .css
        }
        
        // SQL detection
        if (text.uppercased().contains("SELECT ") && text.uppercased().contains(" FROM ")) ||
           text.uppercased().contains("INSERT INTO ") || 
           text.uppercased().contains("CREATE TABLE ") {
            return .sql
        }
        
        // XML detection
        if text.contains("<?xml ") || (text.contains("<") && text.contains("/>")) {
            return .xml
        }
        
        // JSON detection
        if (text.hasPrefix("{") && text.hasSuffix("}")) || 
           (text.hasPrefix("[") && text.hasSuffix("]")) {
            let jsonPattern = "\"\\w+\"\\s*:\\s*"
            if let regex = try? NSRegularExpression(pattern: jsonPattern),
               let _ = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                return .json
            }
        }
        
        // Markdown detection
        if text.contains("# ") || text.contains("## ") || 
           (text.contains("```") && text.contains("```")) ||
           text.contains("**") || text.contains("__") {
            return .markdown
        }
        
        // YAML detection
        if text.contains(": ") && !text.contains("{") && hasMultipleLines {
            // Check for typical YAML patterns
            let yamlPattern = "^\\s*\\w+:\\s*\\w+.*$"
            if let regex = try? NSRegularExpression(pattern: yamlPattern, options: .anchorsMatchLines),
               let _ = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                return .yaml
            }
        }
        
        // Bash/Shell detection
        if text.hasPrefix("#!/bin/") || 
           text.contains("chmod ") || text.contains("sudo ") ||
           (text.contains("$(") && text.contains(")")) {
            return .bash
        }
        
        // C/C++ specific detection
        if text.contains("#include") {
            if text.contains("<iostream>") || text.contains("namespace") || 
               text.contains("std::") || text.contains("cout") || text.contains("cin") || 
               text.contains("vector<") || text.contains("template") {
                return .cpp
            } else if text.contains("<stdio.h>") || text.contains("printf") || 
                    text.contains("scanf") || text.contains("malloc") || 
                    text.contains("int main(") {
                return .c
            }
        }
        
        // Java detection
        if text.contains("public class ") || text.contains("public static void main") ||
           text.contains("System.out.println") || text.contains("import java.util.") {
            return .java
        }
        
        // C# detection
        if text.contains("using System;") || text.contains("namespace ") ||
           text.contains("public class ") && text.contains(".NET") {
            return .csharp
        }
        
        // Go detection
        if text.contains("package main") || text.contains("import (") ||
           text.contains("func main()") || text.contains("fmt.Println") {
            return .go
        }
        
        // Rust detection
        if text.contains("fn main()") || text.contains("let mut ") ||
           text.contains("use std::") || text.contains("->") && text.contains("impl") {
            return .rust
        }
        
        // Ruby detection
        if text.contains("def ") && !text.contains(":") ||
           text.contains("require '") || text.contains("puts ") ||
           text.contains("end") && text.contains("do") {
            return .ruby
        }
        
        // PHP detection
        if text.contains("<?php") || text.contains("echo ") ||
           text.contains("$") && hasSemicolons {
            return .php
        }
        
        // Check for code snippets in general
        if hasMultipleLines && (hasCodeIndentation || hasBraces || hasComments) ||
           (hasParentheses && (hasEquals || hasComments)) {
            // If we have code-like structure but couldn't determine the language
            return .clike
        }
        
        return nil
    }
    
    // Helper function to extract file extensions from text (e.g., "MyFile.swift" -> "swift")
    private func extractFileExtension(from text: String) -> String? {
        let pattern = "\\.([a-zA-Z0-9]+)[\\s\\.\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              match.numberOfRanges > 1 else { return nil }
        
        let range = match.range(at: 1)
        if range.location != NSNotFound,
           let swiftRange = Range(range, in: text) {
            return String(text[swiftRange])
        }
        return nil
    }
    
    // Helper function to detect language from file extension
    private func detectLanguageFromExtension(_ ext: String) -> CodeLanguage? {
        let cleanExt = ext.lowercased()
        
        switch cleanExt {
        case "swift": return .swift
        case "py": return .python
        case "js": return .javascript
        case "ts": return .typescript
        case "html", "htm": return .html
        case "css": return .css
        case "c": return .c
        case "cpp", "cc", "cxx": return .cpp
        case "cs": return .csharp
        case "java": return .java
        case "go": return .go
        case "rs": return .rust
        case "rb": return .ruby
        case "php": return .php
        case "sql": return .sql
        case "md", "markdown": return .markdown
        case "json": return .json
        case "xml": return .xml
        case "yaml", "yml": return .yaml
        case "sh", "bash": return .bash
        default: return nil
        }
    }
    
    var formattedCode: AttributedString? {
        guard let language = detectedLanguage, let text = text else { return nil }
        
        // Create a basic attributed string
        var attributed = AttributedString(text)
        
        // Check OS version for proper API usage
        if #available(macOS 12.0, *) {
            // Apply some basic syntax highlighting based on language
            switch language {
            case .swift:
                highlightKeywords(in: &attributed, text: text, keywords: ["func", "let", "var", "if", "else", "guard", "return", "class", "struct", "enum"])
            case .python:
                highlightKeywords(in: &attributed, text: text, keywords: ["def", "class", "if", "else", "elif", "import", "from", "return", "for", "while"])
            case .javascript, .typescript:
                highlightKeywords(in: &attributed, text: text, keywords: ["function", "let", "var", "const", "if", "else", "return", "class", "import", "export"])
            case .html, .xml:
                // Simple tag highlighting
                highlightPattern(in: &attributed, text: text, pattern: "<[^>]+>")
            case .css:
                highlightKeywords(in: &attributed, text: text, keywords: ["margin", "padding", "color", "background", "font-size", "width", "height", "display", "position", "border"])
            case .c:
                highlightKeywords(in: &attributed, text: text, keywords: ["int", "char", "float", "double", "void", "struct", "union", "enum", "typedef", "const", 
                            "if", "else", "for", "while", "switch", "case", "return", "break", "continue", "sizeof"])
            case .cpp:
                highlightKeywords(in: &attributed, text: text, keywords: ["int", "char", "float", "double", "bool", "void", "class", "struct", "enum", "template", 
                            "namespace", "using", "public", "private", "protected", "const", "virtual", "inline",
                            "if", "else", "for", "while", "switch", "case", "return", "new", "delete"])
            case .csharp:
                highlightKeywords(in: &attributed, text: text, keywords: ["using", "namespace", "class", "public", "private", "protected", "static", "void", "int", "string", "bool", "var", "if", "else", "for", "while", "switch", "case", "return"])
            case .java:
                highlightKeywords(in: &attributed, text: text, keywords: ["public", "private", "protected", "class", "interface", "extends", "implements", "static", "final", "void", "int", "String", "boolean", "if", "else", "for", "while", "switch", "case", "return"])
            case .go:
                highlightKeywords(in: &attributed, text: text, keywords: ["package", "import", "func", "var", "const", "type", "struct", "interface", "map", "if", "else", "for", "range", "switch", "case", "return", "go", "chan"])
            case .rust:
                highlightKeywords(in: &attributed, text: text, keywords: ["fn", "let", "mut", "pub", "use", "struct", "enum", "impl", "trait", "if", "else", "match", "for", "while", "loop", "return"])
            case .ruby:
                highlightKeywords(in: &attributed, text: text, keywords: ["def", "class", "module", "require", "include", "attr_accessor", "if", "else", "elsif", "unless", "case", "when", "while", "until", "for", "do", "end", "return"])
            case .php:
                highlightKeywords(in: &attributed, text: text, keywords: ["<?php", "function", "class", "public", "private", "protected", "static", "echo", "print", "if", "else", "elseif", "while", "for", "foreach", "switch", "case", "return"])
            case .sql:
                highlightKeywords(in: &attributed, text: text, keywords: ["SELECT", "FROM", "WHERE", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "GROUP BY", "ORDER BY", "HAVING", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "TABLE", "VIEW", "INDEX"])
            case .markdown:
                highlightPattern(in: &attributed, text: text, pattern: "^#+\\s.+$|\\*\\*.+\\*\\*|__.+__|```.*```")
            case .json:
                highlightPattern(in: &attributed, text: text, pattern: "\"\\w+\"\\s*:")
            case .yaml:
                highlightPattern(in: &attributed, text: text, pattern: "^\\s*\\w+:\\s.*$")
            case .bash:
                highlightKeywords(in: &attributed, text: text, keywords: ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "function", "echo", "export", "source", "sudo", "apt", "brew"])
            case .clike:
                highlightKeywords(in: &attributed, text: text, keywords: ["if", "else", "for", "while", "switch", "case", "class", "struct", "public", "private"])
            }
        }
        
        return attributed
    }
    
    // Simplify the highlighting methods to avoid AttributedString API issues
    @available(macOS 12.0, *)
    private func highlightKeywords(in attributedString: inout AttributedString, text: String, keywords: [String]) {
        for keyword in keywords {
            // Find each keyword with word boundaries
            let pattern = "\\b\(keyword)\\b"
            highlightPattern(in: &attributedString, text: text, pattern: pattern)
        }
    }
    
    @available(macOS 12.0, *)
    private func highlightPattern(in attributedString: inout AttributedString, text: String, pattern: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, range: range)
        
        for match in matches {
            if let range = Range(match.range, in: text) {
                // Convert Swift String range to AttributedString range
                // This is much safer than manual index calculation
                if let attributedRange = Range(range, in: attributedString) {
                    // Use the safer direct property
                    attributedString[attributedRange].foregroundColor = .blue
                }
            }
        }
    }

    // Add a method to get an NSAttributedString instead of AttributedString for older macOS
    func getHighlightedAttributedString() -> NSAttributedString {
        guard let language = detectedLanguage, let text = text else { 
            return NSAttributedString(string: text ?? "")
        }

        let attributedString = NSMutableAttributedString(string: text)
        
        // Keywords for the detected language
        var keywords: [String] = []
        switch language {
        case .swift:
            keywords = ["func", "let", "var", "if", "else", "guard", "return", "class", "struct", "enum"]
        case .python:
            keywords = ["def", "class", "if", "else", "elif", "import", "from", "return", "for", "while"]
        case .javascript, .typescript:
            keywords = ["function", "let", "var", "const", "if", "else", "return", "class", "import", "export"]
        case .html, .xml:
            // For HTML, we need a special pattern
            highlightHTMLTags(in: attributedString)
            return attributedString
        case .css:
            keywords = ["margin", "padding", "color", "background", "font-size", "width", "height", "display", "position", "border"]
        case .c:
            keywords = ["int", "char", "float", "double", "void", "struct", "union", "enum", "typedef", "const", 
                        "if", "else", "for", "while", "switch", "case", "return", "break", "continue", "sizeof"]
        case .cpp:
            keywords = ["int", "char", "float", "double", "bool", "void", "class", "struct", "enum", "template", 
                        "namespace", "using", "public", "private", "protected", "const", "virtual", "inline",
                        "if", "else", "for", "while", "switch", "case", "return", "new", "delete"]
        case .csharp:
            keywords = ["using", "namespace", "class", "public", "private", "protected", "static", "void", "int", "string", "bool", "var", "if", "else", "for", "while", "switch", "case", "return"]
        case .java:
            keywords = ["public", "private", "protected", "class", "interface", "extends", "implements", "static", "final", "void", "int", "String", "boolean", "if", "else", "for", "while", "switch", "case", "return"]
        case .go:
            keywords = ["package", "import", "func", "var", "const", "type", "struct", "interface", "map", "if", "else", "for", "range", "switch", "case", "return", "go", "chan"]
        case .rust:
            keywords = ["fn", "let", "mut", "pub", "use", "struct", "enum", "impl", "trait", "if", "else", "match", "for", "while", "loop", "return"]
        case .ruby:
            keywords = ["def", "class", "module", "require", "include", "attr_accessor", "if", "else", "elsif", "unless", "case", "when", "while", "until", "for", "do", "end", "return"]
        case .php:
            keywords = ["<?php", "function", "class", "public", "private", "protected", "static", "echo", "print", "if", "else", "elseif", "while", "for", "foreach", "switch", "case", "return"]
        case .sql:
            keywords = ["SELECT", "FROM", "WHERE", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "GROUP BY", "ORDER BY", "HAVING", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "TABLE", "VIEW", "INDEX"]
        case .markdown:
            // Special handling for markdown
            highlightPattern("^#+\\s.+$|\\*\\*.+\\*\\*|__.+__|```.*```", in: attributedString, withColor: NSColor.blue)
            return attributedString
        case .json:
            // Special handling for JSON
            highlightPattern("\"\\w+\"\\s*:", in: attributedString, withColor: NSColor.blue)
            return attributedString
        case .yaml:
            // Special handling for YAML
            highlightPattern("^\\s*\\w+:\\s.*$", in: attributedString, withColor: NSColor.blue)
            return attributedString
        case .bash:
            keywords = ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "function", "echo", "export", "source", "sudo", "apt", "brew"]
        case .clike:
            keywords = ["if", "else", "for", "while", "switch", "case", "class", "struct", "public", "private"]
        }
        
        // Highlight keywords
        for keyword in keywords {
            let pattern = "\\b\(keyword)\\b"
            highlightPattern(pattern, in: attributedString, withColor: NSColor.blue)
        }
        
        return attributedString
    }

    private func highlightPattern(_ pattern: String, in attributedString: NSMutableAttributedString, withColor color: NSColor) {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: attributedString.length)
        
        regex?.enumerateMatches(in: attributedString.string, range: range) { match, _, _ in
            if let matchRange = match?.range {
                attributedString.addAttribute(.foregroundColor, value: color, range: matchRange)
            }
        }
    }

    private func highlightHTMLTags(in attributedString: NSMutableAttributedString) {
        let pattern = "<[^>]+>"
        highlightPattern(pattern, in: attributedString, withColor: NSColor.blue)
    }
}

// NSImage extensions for optimized processing
extension NSImage {
    func resizedImageData(to newSize: CGSize, compressionQuality: CGFloat = 0.8) -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Create bitmap context with new size
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        bitmapRep?.size = newSize
        
        // Draw the image in the bitmap
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep!)
        NSGraphicsContext.current?.imageInterpolation = .high
        
        let drawRect = NSRect(origin: .zero, size: newSize)
        NSGraphicsContext.current?.cgContext.draw(cgImage, in: drawRect)
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Generate compressed JPEG data
        return bitmapRep?.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    
    func compressedImageData(compressionQuality: CGFloat = 0.8) -> Data? {
        // Create bitmap representation of the image
        if let tiffData = self.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData) {
            // Return JPEG representation at specified quality
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        }
        return nil
    }
    
    // Cache-friendly variant of downsample
    func downsample(to targetSize: CGSize) -> Data? {
        // Use resizedImageData with memory optimization
        return resizedImageData(to: targetSize, compressionQuality: 0.7)
    }
}

// Add image caching for better performance
final class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.clippy.imageCache", qos: .utility)
    
    private init() {
        // Set reasonable memory limits
        cache.countLimit = 50  // Max number of images
        cache.totalCostLimit = 100 * 1024 * 1024  // 100MB limit
    }
    
    func image(for key: String, data: Data) -> NSImage {
        let nsKey = NSString(string: key)
        
        // Check if image is already in cache
        if let cachedImage = cache.object(forKey: nsKey) {
            return cachedImage
        }
        
        // Otherwise create and cache it
        if let image = NSImage(data: data) {
            queue.async { [weak self] in
                self?.cache.setObject(image, forKey: nsKey, cost: data.count)
            }
            return image
        }
        
        // Return empty image as fallback
        return NSImage()
    }
    
    func clearCache() {
        queue.async { [weak self] in
            self?.cache.removeAllObjects()
        }
    }
} 