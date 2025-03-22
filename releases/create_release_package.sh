#!/bin/bash

# Script to create a release package for Clippy v1.0.0

# Create a release directory
mkdir -p Clippy-v1.0.0

# Copy essential files
cp -r ../Clippy ../Clippy.xcodeproj ../CHANGELOG.md ../LICENSE ../README.md ../CONTRIBUTING.md Clippy-v1.0.0/
cp RELEASE-v1.0.0.md Clippy-v1.0.0/

# Create the release archive
zip -r Clippy-v1.0.0.zip Clippy-v1.0.0

# Clean up temporary directory
rm -rf Clippy-v1.0.0

echo "Release package created: Clippy-v1.0.0.zip"
echo "Next steps:"
echo "1. Build the app using Xcode (Product → Archive)"
echo "2. Export the app and create a DMG installer if needed"
echo "3. Create a GitHub release and upload both the app and source code archive" 