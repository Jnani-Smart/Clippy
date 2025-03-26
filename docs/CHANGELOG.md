# Changelog

All notable changes to Clippy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2024-07-21

### Changed
- Redesigned clipboard item options menu to use text-only style
- Improved menu readability and consistency
- Streamlined context menu interface

## [1.3.0] - 2024-03-23

### Added
- Category-based filtering system for clipboard items (text, code, URL, image)
- Custom category-specific empty states with relevant icons and messages
- Improved search functionality with real-time updates
- New Data Management tab in Settings
- Import/Export functionality in the Settings panel

### Changed
- Redesigned clipboard item cards with improved visual hierarchy
- Enhanced UI with animated transitions for smoother experience
- Better Settings window handling with proper window controls
- Improved dialog handling with sheet-style presentation
- Memory optimizations for handling large clipboard histories

### Fixed
- Search functionality issues
- Window handling and focus problems
- Category filtering reliability
- Memory leaks in image handling

## [1.1.0] - 2023-12-18

### Added
- Enhanced UI with improved visual effects and animations
- Better keyboard shortcut management in the settings
- Advanced clipboard item handling

### Changed
- Refactored ClipboardManagerApp.swift with improved initialization process
- Redesigned SettingsView with better macOS integration
- Enhanced ShortcutRecorder implementation
- Updated project structure and organization

### Removed
- Outdated screenshot files
- Redundant releases documentation

## [1.0.0] - 2023-11-12

### Added
- Initial release of Clippy clipboard manager
- Clipboard history tracking for text and images
- Pinned items feature
- Search functionality for clipboard items
- Dark mode support
- Customizable keyboard shortcuts
- Frosted glass UI with macOS Finder-like appearance
- Fade animations for window appearance/disappearance
- Export/import clipboard history 