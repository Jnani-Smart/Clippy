# Changelog

All notable changes to Clippy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.8.0] - 2025-08-19

### Fixed
- Quick Look initialization artifacts and visual glitches during startup
- Improved Quick Look content loading with proper timing and state management
- Enhanced Quick Look preview reliability with better error handling
- Smoother Quick Look animations with content-ready detection

### Changed
- Optimized Quick Look preview initialization process for better user experience
- Enhanced loading states with progress indicators during Quick Look preparation
- Improved Quick Look view lifecycle management for cleaner state transitions
 - Selection mode header: moved Cancel button to the title row (top-right) and removed the Select All/None bar for a cleaner layout
 - Header spacing: aligned the divider between search and segmented control with uniform spacing
 - Hover behavior: limited long-item reveal on hover to maintain consistent row heights (text up to 3 lines, code up to 6 lines)

## [1.7.0] - 2025-07-28

### Added
- Auto-update notifications now show automatically during background checks (not just manual checks)
- Quick Look preview for clipboard items with space bar support
- Smooth fade animations for Quick Look preview window
- Keyboard controls (space and escape) for Quick Look preview
- Dock icon click functionality to open clipboard menu

### Changed
- Enhanced settings window with macOS Finder-like translucency, rounded corners, and smooth animations
- Improved window focus management to appear in current space without forcing to front of full screen apps
- Refined auto-update system to only download updates (manual installation)
- Updated settings window behavior to redirect to existing window without forcing frontmost activation

### Fixed
- Settings window CloseButtonRepresentable crash on first open
- Empty space at top of settings window after first open
- Square artifact in Quick Look preview initialization
- Auto-update notification system to show alerts during automatic background checks

## [1.6.0] - 2025-07-03

### Added
- New app icon with improved high-resolution assets
- More compact selection toolbar in clipboard view
- Optimized About section in Settings to always show the latest icon

### Changed
- Updated all icon assets throughout the app
- Improved icon loading in the About section of Settings
- Streamlined UI components for better alignment and spacing

### Fixed
- Fixed inconsistencies with app icon appearance in various contexts
- Resolved issues with icon caching in macOS

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
