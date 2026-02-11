# Clippy v1.9.0 Release Notes

## UI/UX Enhancements

### Minimalist Onboarding Experience
- **Clean First Launch**: Redesigned onboarding flow with minimal, professional interface
- **Glass Effect Styling**: Beautiful liquid glass effect throughout onboarding screens
- **Streamlined Flow**: Simple 3-step onboarding (Welcome → Permissions → Complete)
- **Hidden Traffic Lights**: Cleaner window appearance with hidden window controls
- **Robust First-Launch Logic**: Improved detection and handling of first-time app launches

### Clipboard Item UI Improvements
- **Unified Backgrounds**: All clipboard items now have consistent grey backgrounds for a cohesive look
- **Reduced Header Padding**: Tightened top padding for more compact, professional appearance
- **Smart Scroll Behavior**: Cards remain compact during scrolling and only expand on hover after scroll stops
- **Improved Spacing**: Better content spacing throughout the clipboard view

### Enhanced Syntax Highlighting for Code Snippets
- **Comprehensive Language Support**: Expanded support for Swift, Python, JavaScript, TypeScript, Go, Rust, Java, Kotlin, C/C++, C#, Ruby, PHP, HTML, CSS, SQL, Shell, and more
- **Rich Keyword Recognition**: Added extensive keyword lists including control flow, declarations, modifiers, and language-specific features
- **Type System Highlighting**: Enhanced type detection for built-in types, common framework types, and custom types
- **Operator and Symbol Highlighting**: Improved recognition of operators, punctuation, and special characters
- **Professional Color Scheme**: Refined color palette with distinct colors for keywords, types, strings, numbers, comments, and operators
- **Better Code Readability**: Improved visual distinction between different code elements for easier scanning

## Technical Improvements
- **AttributedString Integration**: Direct use of AttributedString for more efficient code rendering
- **Pattern Matching**: Enhanced regex-based pattern matching for better syntax detection
- **Performance Optimization**: Improved highlighting performance for long code snippets

# Previous Release: Clippy v1.8.0 Release Notes

## Quick Look Improvements

### Enhanced Preview Initialization
- **Artifact-Free Startup**: Completely eliminated visual glitches and artifacts that appeared when initializing Quick Look preview
- **Smooth Loading Experience**: Added proper loading states with progress indicators while content is being prepared
- **Content-Ready Detection**: Improved timing system that ensures Quick Look content is fully loaded before displaying
- **Better State Management**: Enhanced lifecycle management for cleaner transitions between preview states

### Technical Improvements
- **Optimized Initialization Process**: Quick Look views now initialize asynchronously to prevent visual artifacts
- **Enhanced Error Handling**: Better fallback mechanisms when Quick Look content fails to load
- **Improved Animation Timing**: Animations now properly sync with content readiness for smoother user experience
- **Memory Management**: Better cleanup and state reset between Quick Look sessions

## UI/UX Improvements

- **Selection Mode Refinement**: Cancel button moved to the top-right beside the title; removed Select All/None bar for a more focused UI
- **Header Alignment**: Divider between the search bar and segmented control is now perfectly centered with consistent spacing
- **Consistent Hover Reveal**: Long items now expand slightly on hover (text up to 3 lines, code up to 6 lines) to maintain consistent row heights

## Bug Fixes
- Fixed Quick Look initialization showing temporary artifacts or blank content
- Resolved timing issues where animations would start before content was ready
- Improved Quick Look reliability across different file types and content sources
- Enhanced preview window stability and performance

# Previous Release: Clippy v1.7.0 Release Notes

## Major Enhancements

### Auto-Update System Improvements
- **Automatic Notifications**: Auto-update notifications now show automatically during background checks (not just manual checks)
- **Download-Only Approach**: Refined auto-update system to only download updates (manual installation for better security)
- **Enhanced User Experience**: Users maintain full control over installation timing with no automatic system modifications

### Quick Look Preview Feature
- **Space Bar Preview**: Press space bar to preview clipboard items with native macOS Quick Look integration
- **Smooth Animations**: Fast fade in/out animations (0.25s fade in, 0.2s fade out) with easeInOut timing
- **Keyboard Controls**: Space and escape keys now close Quick Look preview
- **Artifact-Free Initialization**: Completely fixed square artifact that appeared during preview initialization

### Settings Window Enhancements
- **Enhanced Visual Design**: Floating panel with macOS Finder-like translucency, rounded corners, and smooth animations
- **Improved Window Management**: Settings window properly appears in current space without forcing to front of full screen apps
- **Dock Integration**: Open clipboard menu directly from dock icon click
- **Stability Improvements**: Fixed CloseButtonRepresentable crash on first open and empty space at top after first open

## Bug Fixes
- Fixed settings window CloseButtonRepresentable crash on first open
- Resolved empty space at top of settings window after first open
- Eliminated square artifact in Quick Look preview initialization
- Enhanced auto-update notification system to show alerts during automatic background checks

# Previous Release: Clippy v1.6.0

## VisionOS-Style Interface
- **Modern Glass Effect UI** with dynamic blur and subtle shadows
- **Enhanced Visual Effects** throughout the app with VisionOS-inspired design
- **Improved Animations** with physics-based interactions and smooth transitions
- **Beautiful Empty States** with contextual messages and animations
- **Enhanced Confetti Effects** with improved physics and visual appeal

### Enhanced UI and User Experience
- **Redesigned Clipboard Items** with modern glass effect and improved interactivity
- **Enhanced Category Filtering** with animated transitions and visual feedback
- **Improved Search Experience** with real-time updates and optimized performance
- **Auto-Update System** with version checking and update notifications
- **Enhanced Visual Hierarchy** with improved spacing and layout

### Improved Window Management
- **Better Settings window handling** with proper window controls
- **ESC key support** for dismissing settings panel
- **Enhanced visual effects** with premium glass background

### Data Management
- **New Data Management Tab** in Settings
- **Import/Export functionality** for clipboard history moved to Settings panel
- **Improved dialog handling** with sheet-style presentation

### Performance Improvements
- **Optimized animations** with spring effects for better responsiveness
- **Memory optimizations** for handling large clipboard histories
- **More efficient image loading** for better performance

## Bug Fixes
- Fixed search functionality issues
- Improved window handling and focus
- Enhanced category filtering reliability
- Fixed memory leaks in image handling

## Technical Improvements
- Code organization with separate files for UI components
- Better architecture with separated responsibilities
- Improved notification handling for real-time updates