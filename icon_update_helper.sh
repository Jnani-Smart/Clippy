#!/bin/bash

# Icon Update Helper Script
# This script helps with updating the app icon across the entire Clippy application

echo "===== CLIPPY ICON UPDATE HELPER ====="
echo "This script will help you update the app icon throughout the Clippy application."
echo

# Define paths
WORKSPACE_DIR="/Users/jnanismart/Clippy"
ICNS_FILE="$WORKSPACE_DIR/Clippy/AppIcon.icns"
ASSET_DIR="$WORKSPACE_DIR/Clippy/Assets.xcassets/AppIcon.appiconset"
TEMP_DIR="$WORKSPACE_DIR/temp_icons"

# Check if the ICNS file exists
if [ ! -f "$ICNS_FILE" ]; then
    echo "Error: AppIcon.icns not found at $ICNS_FILE"
    echo "Please place your AppIcon.icns file in the Clippy/Clippy directory."
    exit 1
fi

# Main menu
while true; do
    echo "======================================"
    echo "ICON UPDATE OPTIONS:"
    echo "1. Extract icons from AppIcon.icns to asset catalog"
    echo "2. Clean Xcode's DerivedData"
    echo "3. Build the app"
    echo "4. Clear macOS icon caches"
    echo "5. Run comprehensive icon update (all of the above)"
    echo "6. Exit"
    echo "======================================"
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1)  # Extract icons
            echo "Extracting icons from AppIcon.icns..."
            mkdir -p "$TEMP_DIR"
            
            # Define the icon sizes needed for macOS
            declare -a sizes=("16" "32" "128" "256" "512")
            
            # Extract icons to temp directory using sips
            for size in "${sizes[@]}"; do
                echo "Extracting ${size}×${size} icon..."
                
                # Extract at 1x
                sips -s format png --out "$TEMP_DIR/icon_${size}x${size}.png" --resampleHeightWidth "$size" "$size" "$ICNS_FILE" > /dev/null
                
                # Extract at 2x (double size) where needed
                double_size=$((size * 2))
                sips -s format png --out "$TEMP_DIR/icon_${size}x${size}@2x.png" --resampleHeightWidth "$double_size" "$double_size" "$ICNS_FILE" > /dev/null
            done
            
            # Special case for 1024x1024 (needed for 512x512@2x)
            sips -s format png --out "$TEMP_DIR/icon_1024x1024.png" --resampleHeightWidth 1024 1024 "$ICNS_FILE" > /dev/null
            
            # Copy the extracted icons to the Assets.xcassets folder
            echo "Copying icons to AppIcon.appiconset..."
            
            # Copy the standard required sizes for macOS
            cp "$TEMP_DIR/icon_16x16.png" "$ASSET_DIR/icon_16x16.png"
            cp "$TEMP_DIR/icon_16x16@2x.png" "$ASSET_DIR/icon_16x16@2x.png" 
            cp "$TEMP_DIR/icon_32x32.png" "$ASSET_DIR/icon_32x32.png"
            cp "$TEMP_DIR/icon_32x32@2x.png" "$ASSET_DIR/icon_32x32@2x.png" 
            cp "$TEMP_DIR/icon_128x128.png" "$ASSET_DIR/icon_128x128.png"
            cp "$TEMP_DIR/icon_128x128@2x.png" "$ASSET_DIR/icon_128x128@2x.png" 
            cp "$TEMP_DIR/icon_256x256.png" "$ASSET_DIR/icon_256x256.png"
            cp "$TEMP_DIR/icon_256x256@2x.png" "$ASSET_DIR/icon_256x256@2x.png" 
            cp "$TEMP_DIR/icon_512x512.png" "$ASSET_DIR/icon_512x512.png"
            cp "$TEMP_DIR/icon_1024x1024.png" "$ASSET_DIR/icon_512x512@2x.png" 
            
            # Clean up temporary directory
            rm -rf "$TEMP_DIR"
            echo "All icons in asset catalog have been updated."
            ;;
        2)  # Clean Xcode's DerivedData
            echo "Cleaning Xcode's DerivedData..."
            rm -rf ~/Library/Developer/Xcode/DerivedData/Clippy-*
            echo "Cleaned DerivedData folder."
            ;;
        3)  # Build the app
            echo "Building the app..."
            cd "$WORKSPACE_DIR"
            xcodebuild -scheme Clippy -configuration Debug clean build
            
            # Find the built app
            APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Clippy.app" -type d | grep -v "Build/Intermediates" | head -1)
            if [ -z "$APP_PATH" ]; then
                echo "Error: Could not find built Clippy.app"
            else
                echo "App built successfully at: $APP_PATH"
            fi
            ;;
        4)  # Clear macOS icon caches
            echo "Clearing macOS icon caches..."
            echo "This may require your password."
            sudo find /private/var/folders -name com.apple.dock.iconcache -delete 2>/dev/null || true
            sudo find /private/var/folders -name com.apple.iconservices -exec rm -rf {} \; 2>/dev/null || true
            sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
            
            echo "Restarting Finder and Dock..."
            killall Finder Dock SystemUIServer 2>/dev/null || true
            echo "Icon caches cleared."
            ;;
        5)  # Run comprehensive update
            echo "Running comprehensive icon update..."
            
            # Extract icons
            echo "Step 1: Updating all icons in the asset catalog..."
            mkdir -p "$TEMP_DIR"
            
            # Define the icon sizes needed for macOS
            declare -a sizes=("16" "32" "128" "256" "512")
            
            # Extract icons to temp directory using sips
            for size in "${sizes[@]}"; do
                echo "Extracting ${size}×${size} icon..."
                
                # Extract at 1x
                sips -s format png --out "$TEMP_DIR/icon_${size}x${size}.png" --resampleHeightWidth "$size" "$size" "$ICNS_FILE" > /dev/null
                
                # Extract at 2x (double size) where needed
                double_size=$((size * 2))
                sips -s format png --out "$TEMP_DIR/icon_${size}x${size}@2x.png" --resampleHeightWidth "$double_size" "$double_size" "$ICNS_FILE" > /dev/null
            done
            
            # Special case for 1024x1024 (needed for 512x512@2x)
            sips -s format png --out "$TEMP_DIR/icon_1024x1024.png" --resampleHeightWidth 1024 1024 "$ICNS_FILE" > /dev/null
            
            # Copy the extracted icons to the Assets.xcassets folder
            echo "Copying icons to AppIcon.appiconset..."
            
            # Copy the standard required sizes for macOS
            cp "$TEMP_DIR/icon_16x16.png" "$ASSET_DIR/icon_16x16.png"
            cp "$TEMP_DIR/icon_16x16@2x.png" "$ASSET_DIR/icon_16x16@2x.png" 
            cp "$TEMP_DIR/icon_32x32.png" "$ASSET_DIR/icon_32x32.png"
            cp "$TEMP_DIR/icon_32x32@2x.png" "$ASSET_DIR/icon_32x32@2x.png" 
            cp "$TEMP_DIR/icon_128x128.png" "$ASSET_DIR/icon_128x128.png"
            cp "$TEMP_DIR/icon_128x128@2x.png" "$ASSET_DIR/icon_128x128@2x.png" 
            cp "$TEMP_DIR/icon_256x256.png" "$ASSET_DIR/icon_256x256.png"
            cp "$TEMP_DIR/icon_256x256@2x.png" "$ASSET_DIR/icon_256x256@2x.png" 
            cp "$TEMP_DIR/icon_512x512.png" "$ASSET_DIR/icon_512x512.png"
            cp "$TEMP_DIR/icon_1024x1024.png" "$ASSET_DIR/icon_512x512@2x.png" 
            
            # Clean up temporary directory
            rm -rf "$TEMP_DIR"
            echo "All icons in asset catalog have been updated."
            
            # Clean DerivedData
            echo "Step 2: Cleaning Xcode's DerivedData..."
            rm -rf ~/Library/Developer/Xcode/DerivedData/Clippy-*
            echo "Cleaned DerivedData folder."
            
            # Build the app
            echo "Step 3: Building the app..."
            cd "$WORKSPACE_DIR"
            xcodebuild -scheme Clippy -configuration Debug clean build
            
            # Find the built app
            APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Clippy.app" -type d | grep -v "Build/Intermediates" | head -1)
            if [ -z "$APP_PATH" ]; then
                echo "Error: Could not find built Clippy.app"
                exit 1
            fi
            
            echo "App built successfully at: $APP_PATH"
            
            # Ensure AppIcon.icns is in the app bundle
            echo "Step 4: Ensuring AppIcon.icns is in the app bundle..."
            APP_RESOURCES="$APP_PATH/Contents/Resources"
            if [ ! -f "$APP_RESOURCES/AppIcon.icns" ]; then
                echo "Copying AppIcon.icns to app resources..."
                cp "$ICNS_FILE" "$APP_RESOURCES/"
            else
                echo "AppIcon.icns is already in the app bundle."
            fi
            
            # Clear icon caches
            echo "Step 5: Clearing macOS icon caches..."
            echo "This may require your password."
            sudo find /private/var/folders -name com.apple.dock.iconcache -delete 2>/dev/null || true
            sudo find /private/var/folders -name com.apple.iconservices -exec rm -rf {} \; 2>/dev/null || true
            sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
            
            echo "Restarting Finder and Dock..."
            killall Finder Dock SystemUIServer 2>/dev/null || true
            
            echo "Comprehensive update completed!"
            echo "To open the app, run: open \"$APP_PATH\""
            ;;
        6)  # Exit
            echo "Exiting..."
            exit 0
            ;;
        *)  # Invalid option
            echo "Invalid option. Please enter a number between 1 and 6."
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    clear
done
