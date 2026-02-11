# Clippy User Guide

Welcome to Clippy, a modern clipboard manager for macOS featuring a beautiful VisionOS-inspired interface. This guide will help you make the most of Clippy's features.

## Getting Started

### Installation

1. Download the latest version of Clippy from the [releases page](https://github.com/Jnani-Smart/Clippy/releases)
2. Drag Clippy to your Applications folder
3. Open Clippy from your Applications folder

### First Run Setup

When you first launch Clippy, you'll experience a minimalist onboarding flow:

1. **Welcome Screen**: Introduction to Clippy with clean glass effect styling
2. **Permissions**: Allow Accessibility permissions (needed to capture clipboard changes)
3. **Complete**: Choose whether to launch Clippy at login (recommended)

The onboarding features a professional, minimal design with hidden window controls for a cleaner appearance.

## Basic Usage

### Accessing Clipboard History

- Press the default keyboard shortcut **⌘+⇧+V** to open the Clippy window
- Browse your clipboard history
- Click on any item to copy it to the clipboard and paste to the frontmost application

### Item Options Menu

- Right-click (or control-click) on any clipboard item to access the options menu
- The options menu features a modern glass effect design with smooth animations
- Available options include:
  - Copy: Copy the item to clipboard without pasting
  - Pin/Unpin: Toggle pinned status for the item with visual feedback
  - Delete: Remove the item with fade-out animation
  - Format-specific options (like "Open URL" for links or "Save Image" for images)
  - Each action features subtle hover effects and transitions

### Search

- When the Clippy window is open, start typing to search
- Results filter in real-time with smooth animations
- Enhanced search with category-aware filtering
- Beautiful empty states with contextual messages
- Search works across all categories with optimized performance

### Code Snippet Highlighting

- Code snippets are automatically detected and highlighted with professional syntax coloring
- Supports 15+ programming languages including Swift, Python, JavaScript, TypeScript, Go, Rust, Java, and more
- Rich highlighting for keywords, types, operators, strings, numbers, and comments
- Distinct color scheme for easy code readability and scanning

### Category Filtering

- Click the category filter button (three horizontal lines) in the search bar to show/hide categories
- Select a category (Text, Code, URL, Image) to filter your clipboard items by type
- Each category has its own unique icon and color for easy identification
- Click "All" to show all clipboard items again

### Pinning Items

To keep important items easily accessible:

1. Hover over any clipboard item
2. Click the pin icon that appears
3. Access pinned items from the "Pinned" tab

### Quick Look Preview

- Press the Space bar to preview items with native macOS Quick Look
- Smooth fade animations; press Space or Escape to close
- Initialization is artifact-free with proper loading states

### Selection Mode

- Enter selection mode from the context menu
- The Cancel button appears in the top-right beside the title
- The previous Select All/None bar has been removed for a cleaner layout

### Hover Behavior

- Hovering over items reveals a small additional portion of content
- To preserve consistent row heights, text reveals up to 3 lines, and code up to 6 lines
- Cards remain compact during scrolling for smoother navigation
- Expansion only occurs on hover after scrolling has stopped

### Visual Consistency

- All clipboard items feature unified grey backgrounds for a cohesive, professional appearance
- Reduced header padding provides a more compact layout
- Improved spacing throughout the interface for better visual hierarchy

## Advanced Features

### Customizing Keyboard Shortcuts

1. Click the gear icon in the Clippy window
2. Go to the "Shortcuts" tab
3. Click the shortcut field to record a new keyboard shortcut

### Data Management

Clippy provides robust data management features:

1. Click the gear icon to access Settings
2. Navigate to the "Data Management" tab
3. Use the Export button to save your clipboard history as a JSON file
4. Use the Import button to restore a previously exported history

### Clearing History

- Click the "Clear" button to remove all non-pinned items from your clipboard history

## Troubleshooting

### Clippy Doesn't Start

- Ensure Clippy has necessary permissions in System Preferences → Security & Privacy → Accessibility
- Check if there's a conflicting app using the same keyboard shortcut

### Items Not Being Captured

- Make sure Clippy is running
- Check that you haven't exceeded the maximum history size in settings

### Search Not Working

- Try clicking in the search field and typing again
- Clear the search field and start over
- Check if category filtering is active and restricting the results

## Getting Help

If you encounter issues not covered in this guide:

- Check the [GitHub Issues page](https://github.com/YOUR_USERNAME/Clippy/issues) for known problems
- Submit a new issue if your problem hasn't been reported

## Privacy

Clippy respects your privacy:

- All clipboard data is stored locally on your computer
- No data is sent to external servers
- Sensitive clipboard items from password managers are automatically excluded