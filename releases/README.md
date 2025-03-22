# Clippy Releases

This directory contains release packages for Clippy.

## Current Release

### v1.0.0 (2023-11-12)
- **Source Code**: [Clippy-v1.0.0.zip](./Clippy-v1.0.0.zip)
- **Release Notes**: [RELEASE-v1.0.0.md](./RELEASE-v1.0.0.md)

## Building the App

To build the app from source:

1. Open the Clippy.xcodeproj in Xcode
2. Select "Product" → "Archive" from the menu
3. Follow the steps to export the app with your developer certificate
4. Optionally create a DMG installer using the create-dmg tool:
   ```
   brew install create-dmg
   create-dmg \
     --volname "Clippy Installer" \
     --volicon "../icon.png" \
     --window-pos 200 120 \
     --window-size 600 400 \
     --icon-size 100 \
     --icon "Clippy.app" 150 180 \
     --app-drop-link 450 180 \
     --hide-extension "Clippy.app" \
     "Clippy.dmg" \
     "path/to/exported/Clippy.app"
   ```

## Publishing a New Release

1. Update the version in Xcode and CHANGELOG.md
2. Create a Git tag: `git tag -a vX.Y.Z -m "Release message"`
3. Create a release package using the script: `./create_release_package.sh`
4. Build the app and create installer
5. Create a new release on GitHub and upload the files 