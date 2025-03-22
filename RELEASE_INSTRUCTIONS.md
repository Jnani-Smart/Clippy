# Creating a Release for Clippy

Follow these steps to create a release for Clippy and publish it on GitHub:

## 1. Prepare the App for Distribution

1. Open Xcode and select your project
2. Select the Clippy target and go to the "Signing & Capabilities" tab
3. Ensure you have a valid Developer ID certificate selected
4. Update the version number in the "General" tab
5. Make any final changes and commit them to your repository

## 2. Archive the App

1. Select "Product" → "Archive" from Xcode menu
2. Wait for the archiving process to complete
3. In the Archives window, select your build and click "Distribute App"
4. Choose "Developer ID" → "Upload"
5. Follow the steps to sign and export your app

## 3. Create a DMG Installer (Optional)

For a better user experience, you can create a DMG installer:

1. Install `create-dmg` tool: `brew install create-dmg`
2. Create a DMG file:
   ```
   create-dmg \
     --volname "Clippy Installer" \
     --volicon "icon.png" \
     --window-pos 200 120 \
     --window-size 600 400 \
     --icon-size 100 \
     --icon "Clippy.app" 150 180 \
     --app-drop-link 450 180 \
     --hide-extension "Clippy.app" \
     "Clippy.dmg" \
     "path/to/exported/Clippy.app"
   ```

## 4. Create a GitHub Release

1. Go to your GitHub repository
2. Click on "Releases" → "Create a new release"
3. Enter a tag version (e.g., v1.0.0)
4. Enter a release title (e.g., Clippy v1.0.0)
5. Write release notes describing:
   - New features
   - Bug fixes
   - Known issues
   - Installation instructions
6. Attach the .app file or .dmg installer
7. Select "Publish release"

## 5. Update Documentation

After releasing:

1. Update the download link in README.md with the new release
2. Add release notes to CHANGELOG.md
3. Update version numbers in relevant documentation

## 6. Announce Release

Consider announcing your release on:
- Project website
- Social media
- Relevant forums or communities 