# Changelog

All notable changes to Clippy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2024-09-20

### Added
- VisionOS-style visual effects and animations throughout the app
- Enhanced confetti effects with improved physics and visual appeal
- Modern glass effect with dynamic blur and subtle shadows
- Improved category filtering with animated transitions
- Auto-update system with version checking functionality

### Changed
- Completely redesigned UI with VisionOS-inspired aesthetics
- Enhanced button styles with modern glass effects
- Optimized clipboard item display with better performance
- Improved visual hierarchy and spacing in all views
- Enhanced search bar with real-time filtering

### Fixed
- Memory optimization for large clipboard histories
- Performance improvements in image handling and display
- Enhanced state management for better reliability

## [1.4.0] - 2024-08-17

### Added
- Source app information now displayed for each clipboard item
- Improved handling for programming language detection
- Enhanced "Save Image" functionality with standard save dialog
- Redesigned clipboard item rows with VisionOS-inspired aesthetics

### Changed
- Fixed window positioning issue with Mac Spotlight
- Refined hover states and interactive elements for better usability
- Improved visual hierarchy with better spacing and layout
- Updated pin button functionality with smoother animations
- Enhanced context menu with better spacing and alignment

### Fixed
- Compiler errors related to sharing implementation
- Memory management improvements for better performance
- Type inference issues in code display components

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
