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
            // Apply comprehensive syntax highlighting based on language
            switch language {
            case .swift:
                // Swift keywords
                highlightKeywords(in: &attributed, text: text, keywords: [
                    // Declarations
                    "func", "let", "var", "class", "struct", "enum", "protocol", "extension", "typealias", "associatedtype",
                    "init", "deinit", "subscript", "operator", "precedencegroup", "actor", "macro",
                    // Modifiers
                    "public", "private", "fileprivate", "internal", "open", "static", "final", "override", "mutating",
                    "nonmutating", "dynamic", "optional", "required", "convenience", "lazy", "weak", "unowned",
                    "inout", "async", "await", "throws", "rethrows", "nonisolated", "@MainActor", "@Sendable",
                    // Control flow
                    "if", "else", "guard", "switch", "case", "default", "for", "in", "while", "repeat", "do",
                    "break", "continue", "fallthrough", "return", "throw", "defer", "where",
                    // Expressions
                    "try", "catch", "as", "is", "super", "self", "Self", "nil", "true", "false",
                    "import", "get", "set", "willSet", "didSet", "some", "any"
                ])
                // Swift types
                highlightTypes(in: &attributed, text: text, types: [
                    "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "Optional",
                    "Any", "AnyObject", "Void", "Never", "Result", "Error", "Codable", "Hashable", "Equatable",
                    "Comparable", "Identifiable", "ObservableObject", "Published", "State", "Binding", "View"
                ])
                
            case .python:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    // Keywords
                    "def", "class", "lambda", "if", "elif", "else", "for", "while", "break", "continue",
                    "return", "yield", "pass", "raise", "try", "except", "finally", "with", "as", "assert",
                    "import", "from", "global", "nonlocal", "del", "in", "not", "and", "or", "is",
                    "async", "await", "match", "case",
                    // Built-in constants
                    "True", "False", "None"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "str", "int", "float", "bool", "list", "dict", "set", "tuple", "bytes", "bytearray",
                    "range", "type", "object", "Exception", "self", "cls"
                ])
                // Python decorators
                highlightPattern(in: &attributed, text: text, pattern: "@\\w+", color: .yellow)
                
            case .javascript:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    // Declarations
                    "function", "var", "let", "const", "class", "extends", "static", "get", "set",
                    // Control flow
                    "if", "else", "switch", "case", "default", "for", "while", "do", "break", "continue",
                    "return", "throw", "try", "catch", "finally",
                    // Operators & expressions
                    "new", "delete", "typeof", "instanceof", "in", "of", "void", "yield", "await", "async",
                    // Modules
                    "import", "export", "from", "as", "default",
                    // Other
                    "this", "super", "debugger", "with"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "true", "false", "null", "undefined", "NaN", "Infinity",
                    "Object", "Array", "String", "Number", "Boolean", "Function", "Symbol", "BigInt",
                    "Promise", "Map", "Set", "WeakMap", "WeakSet", "Date", "RegExp", "Error", "JSON", "Math",
                    "console", "window", "document", "fetch", "setTimeout", "setInterval"
                ])
                // Arrow functions
                highlightPattern(in: &attributed, text: text, pattern: "=>", color: .pink)
                
            case .typescript:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    // JavaScript keywords
                    "function", "var", "let", "const", "class", "extends", "static", "get", "set",
                    "if", "else", "switch", "case", "default", "for", "while", "do", "break", "continue",
                    "return", "throw", "try", "catch", "finally", "new", "delete", "typeof", "instanceof",
                    "import", "export", "from", "as", "default", "this", "super", "async", "await", "yield",
                    // TypeScript specific
                    "type", "interface", "enum", "namespace", "module", "declare", "abstract", "implements",
                    "readonly", "private", "protected", "public", "override", "satisfies",
                    "keyof", "infer", "is", "asserts", "never", "unknown"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "true", "false", "null", "undefined", "void", "any", "string", "number", "boolean",
                    "object", "symbol", "bigint", "Array", "Promise", "Partial", "Required", "Readonly",
                    "Record", "Pick", "Omit", "Exclude", "Extract", "NonNullable", "ReturnType", "Parameters"
                ])
                highlightPattern(in: &attributed, text: text, pattern: "=>", color: .pink)
                
            case .html, .xml:
                // Tags
                highlightPattern(in: &attributed, text: text, pattern: "</?\\w+", color: .pink)
                highlightPattern(in: &attributed, text: text, pattern: "/?>", color: .pink)
                // Attributes
                highlightPattern(in: &attributed, text: text, pattern: "\\s\\w+(?==)", color: .orange)
                // Attribute values
                highlightPattern(in: &attributed, text: text, pattern: "=\"[^\"]*\"", color: .green)
                
            case .css:
                // Properties
                highlightKeywords(in: &attributed, text: text, keywords: [
                    "margin", "padding", "border", "width", "height", "max-width", "min-width", "max-height", "min-height",
                    "display", "position", "top", "right", "bottom", "left", "z-index", "float", "clear",
                    "flex", "flex-direction", "flex-wrap", "justify-content", "align-items", "align-content", "gap",
                    "grid", "grid-template", "grid-column", "grid-row", "grid-gap",
                    "color", "background", "background-color", "background-image", "opacity",
                    "font", "font-size", "font-weight", "font-family", "line-height", "text-align", "text-decoration",
                    "transform", "transition", "animation", "box-shadow", "border-radius", "overflow", "cursor",
                    "content", "visibility", "pointer-events"
                ])
                // Selectors (. and #)
                highlightPattern(in: &attributed, text: text, pattern: "[.#][\\w-]+", color: .yellow)
                // Values with units
                highlightPattern(in: &attributed, text: text, pattern: "\\d+(\\.\\d+)?(px|em|rem|%|vh|vw|deg|s|ms)", color: .cyan)
                // Colors
                highlightPattern(in: &attributed, text: text, pattern: "#[0-9a-fA-F]{3,8}", color: .green)
                
            case .c:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    // Types
                    "int", "char", "float", "double", "void", "long", "short", "signed", "unsigned",
                    "struct", "union", "enum", "typedef", "sizeof", "const", "volatile", "static", "extern",
                    "register", "auto", "inline", "restrict", "_Bool", "_Complex", "_Imaginary",
                    // Control flow
                    "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
                    "return", "goto",
                    // Preprocessor (without #)
                    "define", "include", "ifdef", "ifndef", "endif", "pragma"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "NULL", "true", "false", "size_t", "FILE", "stdin", "stdout", "stderr"
                ])
                // Preprocessor directives
                highlightPattern(in: &attributed, text: text, pattern: "#\\w+", color: .purple)
                
            case .cpp:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    // C keywords
                    "int", "char", "float", "double", "void", "long", "short", "signed", "unsigned",
                    "struct", "union", "enum", "typedef", "sizeof", "const", "volatile", "static", "extern",
                    "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "return", "goto",
                    // C++ specific
                    "class", "public", "private", "protected", "virtual", "override", "final", "explicit",
                    "template", "typename", "namespace", "using", "new", "delete", "this", "friend",
                    "inline", "constexpr", "consteval", "constinit", "mutable", "noexcept", "nullptr",
                    "try", "catch", "throw", "static_cast", "dynamic_cast", "const_cast", "reinterpret_cast",
                    "auto", "decltype", "concept", "requires", "co_await", "co_yield", "co_return"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "bool", "true", "false", "nullptr", "NULL", "string", "vector", "map", "set", "list",
                    "shared_ptr", "unique_ptr", "weak_ptr", "optional", "variant", "any", "tuple", "pair",
                    "size_t", "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t"
                ])
                highlightPattern(in: &attributed, text: text, pattern: "#\\w+", color: .purple)
                highlightPattern(in: &attributed, text: text, pattern: "std::\\w+", color: .teal)
                
            case .csharp:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    // Modifiers
                    "public", "private", "protected", "internal", "static", "readonly", "const", "volatile",
                    "virtual", "override", "abstract", "sealed", "partial", "async", "await", "extern",
                    // Declarations
                    "class", "struct", "interface", "enum", "delegate", "event", "namespace", "using",
                    "record", "init", "required",
                    // Control flow
                    "if", "else", "switch", "case", "default", "for", "foreach", "while", "do",
                    "break", "continue", "return", "throw", "try", "catch", "finally", "goto",
                    "yield", "lock", "checked", "unchecked", "fixed", "stackalloc",
                    // Operators
                    "new", "typeof", "sizeof", "nameof", "is", "as", "in", "out", "ref", "params",
                    "this", "base", "where", "when", "and", "or", "not", "with"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "void", "var", "dynamic", "object", "string", "bool", "byte", "sbyte", "char",
                    "short", "ushort", "int", "uint", "long", "ulong", "float", "double", "decimal",
                    "true", "false", "null", "default",
                    "Task", "List", "Dictionary", "IEnumerable", "Action", "Func", "Nullable"
                ])
                // Attributes
                highlightPattern(in: &attributed, text: text, pattern: "\\[\\w+.*?\\]", color: .yellow)
                
            case .java:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    // Modifiers
                    "public", "private", "protected", "static", "final", "abstract", "synchronized",
                    "volatile", "transient", "native", "strictfp", "default",
                    // Declarations
                    "class", "interface", "enum", "extends", "implements", "package", "import",
                    "record", "sealed", "non-sealed", "permits", "var",
                    // Control flow
                    "if", "else", "switch", "case", "for", "while", "do", "break", "continue",
                    "return", "throw", "throws", "try", "catch", "finally", "assert",
                    // Other
                    "new", "instanceof", "this", "super"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "void", "boolean", "byte", "char", "short", "int", "long", "float", "double",
                    "true", "false", "null",
                    "String", "Object", "Integer", "Long", "Double", "Float", "Boolean", "Character",
                    "List", "ArrayList", "Map", "HashMap", "Set", "HashSet", "Optional", "Stream"
                ])
                // Annotations
                highlightPattern(in: &attributed, text: text, pattern: "@\\w+", color: .yellow)
                
            case .go:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    "package", "import", "func", "var", "const", "type", "struct", "interface", "map",
                    "chan", "go", "select", "defer", "range",
                    "if", "else", "switch", "case", "default", "for", "break", "continue", "goto",
                    "return", "fallthrough"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "bool", "string", "int", "int8", "int16", "int32", "int64",
                    "uint", "uint8", "uint16", "uint32", "uint64", "uintptr",
                    "byte", "rune", "float32", "float64", "complex64", "complex128",
                    "true", "false", "nil", "iota",
                    "error", "any", "comparable"
                ])
                // Package references
                highlightPattern(in: &attributed, text: text, pattern: "\\w+\\.", color: .teal)
                
            case .rust:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    "fn", "let", "mut", "const", "static", "pub", "priv", "mod", "use", "crate", "super", "self",
                    "struct", "enum", "trait", "impl", "type", "where", "as", "dyn", "unsafe", "extern",
                    "async", "await", "move", "ref", "box",
                    "if", "else", "match", "loop", "while", "for", "in", "break", "continue", "return"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "bool", "char", "str", "i8", "i16", "i32", "i64", "i128", "isize",
                    "u8", "u16", "u32", "u64", "u128", "usize", "f32", "f64",
                    "true", "false", "Some", "None", "Ok", "Err", "Self",
                    "String", "Vec", "Box", "Rc", "Arc", "Option", "Result", "HashMap", "HashSet"
                ])
                // Lifetimes
                highlightPattern(in: &attributed, text: text, pattern: "'\\w+", color: .yellow)
                // Macros
                highlightPattern(in: &attributed, text: text, pattern: "\\w+!", color: .purple)
                
            case .ruby:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    "def", "class", "module", "end", "if", "elsif", "else", "unless", "case", "when",
                    "while", "until", "for", "do", "begin", "rescue", "ensure", "raise", "retry", "redo",
                    "return", "yield", "break", "next", "super", "self", "nil", "true", "false",
                    "and", "or", "not", "in", "then", "defined?", "alias", "undef",
                    "require", "require_relative", "include", "extend", "prepend",
                    "attr_reader", "attr_writer", "attr_accessor", "private", "protected", "public"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "Array", "Hash", "String", "Integer", "Float", "Symbol", "Range", "Regexp",
                    "Proc", "Lambda", "Object", "Class", "Module", "Struct", "OpenStruct"
                ])
                // Symbols
                highlightPattern(in: &attributed, text: text, pattern: ":\\w+", color: .cyan)
                // Instance/class variables
                highlightPattern(in: &attributed, text: text, pattern: "@{1,2}\\w+", color: .orange)
                
            case .php:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    "function", "class", "interface", "trait", "extends", "implements", "namespace", "use",
                    "public", "private", "protected", "static", "final", "abstract", "const", "readonly",
                    "if", "elseif", "else", "switch", "case", "default", "for", "foreach", "while", "do",
                    "break", "continue", "return", "throw", "try", "catch", "finally",
                    "new", "clone", "instanceof", "echo", "print", "die", "exit", "include", "require",
                    "include_once", "require_once", "global", "as", "match", "fn", "enum"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "true", "false", "null", "self", "parent", "static",
                    "void", "bool", "int", "float", "string", "array", "object", "callable", "iterable", "mixed", "never"
                ])
                // Variables
                highlightPattern(in: &attributed, text: text, pattern: "\\$\\w+", color: .orange)
                
            case .sql:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    // Commands
                    "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "BETWEEN", "LIKE", "IS", "NULL",
                    "ORDER", "BY", "ASC", "DESC", "LIMIT", "OFFSET", "GROUP", "HAVING", "DISTINCT",
                    "JOIN", "INNER", "LEFT", "RIGHT", "OUTER", "FULL", "CROSS", "ON", "USING",
                    "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "TRUNCATE",
                    "CREATE", "ALTER", "DROP", "TABLE", "VIEW", "INDEX", "DATABASE", "SCHEMA",
                    "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "UNIQUE", "CHECK", "DEFAULT", "AUTO_INCREMENT",
                    "UNION", "ALL", "EXCEPT", "INTERSECT", "EXISTS", "CASE", "WHEN", "THEN", "ELSE", "END", "AS",
                    "BEGIN", "COMMIT", "ROLLBACK", "TRANSACTION", "GRANT", "REVOKE"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "INT", "INTEGER", "BIGINT", "SMALLINT", "TINYINT", "FLOAT", "DOUBLE", "DECIMAL", "NUMERIC",
                    "VARCHAR", "CHAR", "TEXT", "BLOB", "DATE", "TIME", "DATETIME", "TIMESTAMP", "BOOLEAN",
                    "TRUE", "FALSE", "NULL", "COUNT", "SUM", "AVG", "MIN", "MAX"
                ])
                
            case .markdown:
                highlightPattern(in: &attributed, text: text, pattern: "^#{1,6}\\s.+$", color: .purple)
                highlightPattern(in: &attributed, text: text, pattern: "\\*\\*[^*]+\\*\\*", color: .orange)
                highlightPattern(in: &attributed, text: text, pattern: "\\*[^*]+\\*", color: .yellow)
                highlightPattern(in: &attributed, text: text, pattern: "`[^`]+`", color: .teal)
                highlightPattern(in: &attributed, text: text, pattern: "\\[[^\\]]+\\]\\([^)]+\\)", color: .blue)
                highlightPattern(in: &attributed, text: text, pattern: "^\\s*[-*+]\\s", color: .pink)
                highlightPattern(in: &attributed, text: text, pattern: "^\\s*\\d+\\.\\s", color: .pink)
                
            case .json:
                highlightPattern(in: &attributed, text: text, pattern: "\"[^\"]+\"\\s*:", color: .pink)
                highlightPattern(in: &attributed, text: text, pattern: ":\\s*\"[^\"]*\"", color: .green)
                highlightPattern(in: &attributed, text: text, pattern: ":\\s*-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?", color: .cyan)
                highlightPattern(in: &attributed, text: text, pattern: ":\\s*(true|false|null)", color: .orange)
                
            case .yaml:
                highlightPattern(in: &attributed, text: text, pattern: "^\\s*[\\w.-]+:", color: .pink)
                highlightPattern(in: &attributed, text: text, pattern: ":\\s*.+$", color: .green)
                highlightPattern(in: &attributed, text: text, pattern: "^\\s*-\\s", color: .orange)
                highlightPattern(in: &attributed, text: text, pattern: "\\{\\{[^}]+\\}\\}", color: .teal)
                
            case .bash:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done",
                    "case", "esac", "in", "function", "return", "exit", "break", "continue",
                    "local", "export", "readonly", "declare", "typeset", "unset", "shift",
                    "echo", "printf", "read", "source", "eval", "exec", "trap", "wait",
                    "cd", "pwd", "pushd", "popd", "mkdir", "rmdir", "rm", "cp", "mv", "ln",
                    "cat", "head", "tail", "grep", "sed", "awk", "sort", "uniq", "wc", "find", "xargs",
                    "chmod", "chown", "sudo", "su", "apt", "yum", "brew", "npm", "pip", "git", "curl", "wget"
                ])
                // Variables
                highlightPattern(in: &attributed, text: text, pattern: "\\$\\{?\\w+\\}?", color: .orange)
                highlightPattern(in: &attributed, text: text, pattern: "\\$\\([^)]+\\)", color: .teal)
                
            case .clike:
                highlightKeywords(in: &attributed, text: text, keywords: [
                    "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
                    "return", "class", "struct", "enum", "public", "private", "protected", "static",
                    "void", "int", "char", "float", "double", "bool", "const", "new", "delete", "this"
                ])
                highlightTypes(in: &attributed, text: text, types: [
                    "true", "false", "null", "nullptr", "NULL"
                ])
            }
        }
        
        return attributed
    }
    
    // Helper to highlight type names (in a different color than keywords)
    @available(macOS 12.0, *)
    private func highlightTypes(in attributedString: inout AttributedString, text: String, types: [String]) {
        for typeName in types {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: typeName))\\b"
            highlightPattern(in: &attributedString, text: text, pattern: pattern, color: .teal)
        }
    }
    
    // Simplify the highlighting methods to avoid AttributedString API issues
    @available(macOS 12.0, *)
    private func highlightKeywords(in attributedString: inout AttributedString, text: String, keywords: [String]) {
        for keyword in keywords {
            // Find each keyword with word boundaries
            let pattern = "\\b\(keyword)\\b"
            highlightPattern(in: &attributedString, text: text, pattern: pattern, color: .pink) // Keywords in pink/magenta
        }
        
        // Also highlight strings (double and single quotes)
        highlightPattern(in: &attributedString, text: text, pattern: "\"[^\"]*\"|'[^']*'", color: .orange)
        
        // Highlight comments
        highlightPattern(in: &attributedString, text: text, pattern: "//.*$|#.*$", color: .gray)
        highlightPattern(in: &attributedString, text: text, pattern: "/\\*[\\s\\S]*?\\*/", color: .gray)
        
        // Highlight numbers
        highlightPattern(in: &attributedString, text: text, pattern: "\\b\\d+(\\.\\d+)?\\b", color: .cyan)
    }
    
    @available(macOS 12.0, *)
    private func highlightPattern(in attributedString: inout AttributedString, text: String, pattern: String, color: Color = .blue) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, range: range)
        
        for match in matches {
            if let range = Range(match.range, in: text) {
                // Convert Swift String range to AttributedString range
                // This is much safer than manual index calculation
                if let attributedRange = Range(range, in: attributedString) {
                    // Use the safer direct property
                    attributedString[attributedRange].foregroundColor = color
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
    func resizedImageData(to newSize: CGSize, compressionQuality: CGFloat = 0.8, preserveFormat: Bool = true) -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // If preserving format and the image doesn't need resizing, return original data
        if preserveFormat && newSize == self.size {
            return self.tiffRepresentation
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
        
        // When preserving format, try to use PNG for lossless compression
        if preserveFormat {
            return bitmapRep?.representation(using: .png, properties: [:])
        } else {
            // Generate compressed JPEG data only when not preserving format
            return bitmapRep?.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        }
    }
    
    func compressedImageData(compressionQuality: CGFloat = 0.8, preserveFormat: Bool = true) -> Data? {
        // When preserving format, try to return original data or use PNG
        if preserveFormat {
            // Try to preserve original format by returning TIFF representation
            if let tiffData = self.tiffRepresentation {
                return tiffData
            }
        }
        
        // Create bitmap representation of the image
        if let tiffData = self.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData) {
            
            if preserveFormat {
                // Use PNG for lossless compression when preserving format
                return bitmapRep.representation(using: .png, properties: [:])
            } else {
                // Return JPEG representation at specified quality
                return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
            }
        }
        return nil
    }
    
    // Cache-friendly variant of downsample with format preservation
    func downsample(to targetSize: CGSize, preserveFormat: Bool = true) -> Data? {
        // Use resizedImageData with memory optimization and format preservation
        return resizedImageData(to: targetSize, compressionQuality: 0.7, preserveFormat: preserveFormat)
    }
    
    // New function to preserve original image format based on data signature
    func preserveOriginalFormat(from originalData: Data) -> Data? {
        // Detect the original format from the data signature
        let formatType = detectImageFormat(from: originalData)
        
        // If we can preserve the original format, do so
        if let tiffData = self.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData) {
            
            switch formatType {
            case .png:
                return bitmapRep.representation(using: .png, properties: [:])
            case .jpeg:
                // Use high quality JPEG if original was JPEG
                return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.98])
            case .tiff:
                return bitmapRep.representation(using: .tiff, properties: [:])
            case .gif:
                // GIF is complex, use PNG as fallback to preserve quality
                return bitmapRep.representation(using: .png, properties: [:])
            case .bmp:
                return bitmapRep.representation(using: .bmp, properties: [:])
            case .heic, .heif:
                // Use PNG for HEIC/HEIF since we can't easily create those
                return bitmapRep.representation(using: .png, properties: [:])
            case .unknown:
                // Default to PNG for unknown formats
                return bitmapRep.representation(using: .png, properties: [:])
            }
        }
        
        return originalData // Return original if conversion fails
    }
    
    private func detectImageFormat(from data: Data) -> ImageFormat {
        guard data.count >= 12 else { return .unknown }
        
        // Check PNG signature
        if data.count >= 8 && data.subdata(in: 0..<8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return .png
        }
        
        // Check JPEG signature
        if data.count >= 3 && data.subdata(in: 0..<3) == Data([0xFF, 0xD8, 0xFF]) {
            return .jpeg
        }
        
        // Check TIFF signatures (both little and big endian)
        if data.count >= 4 {
            let tiffLE = Data([0x49, 0x49, 0x2A, 0x00])
            let tiffBE = Data([0x4D, 0x4D, 0x00, 0x2A])
            if data.subdata(in: 0..<4) == tiffLE || data.subdata(in: 0..<4) == tiffBE {
                return .tiff
            }
        }
        
        // Check GIF signatures
        if data.count >= 6 {
            if let gif87a = "GIF87a".data(using: .ascii), data.subdata(in: 0..<6) == gif87a {
                return .gif
            }
            if let gif89a = "GIF89a".data(using: .ascii), data.subdata(in: 0..<6) == gif89a {
                return .gif
            }
        }
        
        // Check BMP signature
        if data.count >= 2 && data.subdata(in: 0..<2) == Data([0x42, 0x4D]) {
            return .bmp
        }
        
        // Check HEIC/HEIF signatures (simplified)
        if data.count >= 12 {
            if let ftyp = "ftyp".data(using: .ascii), data.subdata(in: 4..<8) == ftyp {
                if let heic = "heic".data(using: .ascii), data.subdata(in: 8..<12) == heic {
                    return .heic
                }
                if let heif = "heif".data(using: .ascii), data.subdata(in: 8..<12) == heif {
                    return .heif
                }
            }
        }
        
        return .unknown
    }
    
    enum ImageFormat {
        case png, jpeg, tiff, gif, bmp, heic, heif, unknown
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