import Foundation
import SwiftUI

// Extend ClipboardItem to support code syntax detection
extension ClipboardItem {
    var detectedLanguage: CodeLanguage? {
        guard type == .text, let text = text else { return nil }
        
        // Simple language detection based on content
        if text.contains("func ") || text.contains("let ") || text.contains("var ") && text.contains("->") {
            return .swift
        } else if text.contains("def ") && text.contains(":") {
            return .python
        } else if text.contains("function(") || text.contains("() =>") || text.contains("let ") && text.contains(";") {
            return .javascript
        } else if text.contains("<div") || text.contains("<html") {
            return .html
        } else if text.contains("{") && text.contains("}") && (text.contains(";") || text.contains("class")) {
            return .clike
        }
        
        return nil
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
            case .javascript:
                highlightKeywords(in: &attributed, text: text, keywords: ["function", "let", "var", "const", "if", "else", "return", "class", "import", "export"])
            case .html:
                // Simple tag highlighting
                highlightPattern(in: &attributed, text: text, pattern: "<[^>]+>")
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
        case .javascript:
            keywords = ["function", "let", "var", "const", "if", "else", "return", "class", "import", "export"]
        case .html:
            // For HTML, we need a special pattern
            highlightHTMLTags(in: attributedString)
            return attributedString
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

enum CodeLanguage {
    case swift
    case python
    case javascript
    case html
    case clike
} 