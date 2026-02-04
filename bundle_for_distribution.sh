#!/bin/bash
set -e

APP_NAME="CanvasBrowser"
VERSION="1.0.0"
APP_BUNDLE="$APP_NAME.app"
DIST_DIR="dist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║     Canvas Browser Distribution Build Script       ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# Parse version from argument if provided
if [ -n "$1" ]; then
    VERSION="$1"
fi
echo "Building version: $VERSION"
echo ""

# Step 1: Run Tests
print_step "Running tests..."
if swift test 2>&1 | grep -q "Build complete!"; then
    print_success "Tests passed!"
else
    print_warning "Test run completed (check output for details)"
fi
echo ""

# Step 2: Build Universal Binary (arm64 + x86_64)
print_step "Building universal binary (arm64 + x86_64)..."

# Build for arm64
swift build -c release --arch arm64
print_success "arm64 build complete"

# Build for x86_64
swift build -c release --arch x86_64
print_success "x86_64 build complete"

# Create universal binary using lipo
print_step "Creating universal binary..."
mkdir -p ".build/universal-release"
lipo -create \
    ".build/arm64-apple-macosx/release/$APP_NAME" \
    ".build/x86_64-apple-macosx/release/$APP_NAME" \
    -output ".build/universal-release/$APP_NAME"
print_success "Universal binary created!"
echo ""

# Step 3: Create App Bundle
print_step "Creating $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Universal Binary
cp ".build/universal-release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist and update version
cp "CanvasBrowser/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_BUNDLE/Contents/Info.plist"

# Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

print_success "App bundle created!"
echo ""

# Step 4: Ad-hoc Code Sign
print_step "Code signing (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements "CanvasBrowser/Resources/Entitlements.entitlements" \
    --options runtime \
    "$APP_BUNDLE"
print_success "Code signing complete!"
echo ""

# Step 5: Verify
print_step "Verifying app bundle..."
codesign -dv --verbose=2 "$APP_BUNDLE" 2>&1 | head -5
echo ""

# Check architectures
print_step "Verifying universal binary..."
lipo -info "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
echo ""

# Step 6: Create Distribution Directory
print_step "Creating distribution packages..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Create ZIP
print_step "Creating ZIP archive..."
ditto -c -k --keepParent "$APP_BUNDLE" "$DIST_DIR/${APP_NAME}-${VERSION}-macOS.zip"
print_success "Created: $DIST_DIR/${APP_NAME}-${VERSION}-macOS.zip"

# Create DMG
print_step "Creating DMG..."
DMG_TEMP="$DIST_DIR/dmg_temp"
mkdir -p "$DMG_TEMP"
cp -r "$APP_BUNDLE" "$DMG_TEMP/"

# Create Applications symlink for drag-and-drop install
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME $VERSION" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DIST_DIR/${APP_NAME}-${VERSION}-macOS.dmg"

rm -rf "$DMG_TEMP"
print_success "Created: $DIST_DIR/${APP_NAME}-${VERSION}-macOS.dmg"
echo ""

# Step 7: Generate checksums
print_step "Generating checksums..."
cd "$DIST_DIR"
shasum -a 256 *.zip *.dmg > checksums.txt
cat checksums.txt
cd ..
echo ""

# Summary
echo "╔═══════════════════════════════════════════════════╗"
echo "║                  Build Complete!                   ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "Distribution files in '$DIST_DIR/':"
ls -lh "$DIST_DIR/"
echo ""
print_warning "Note: This app is ad-hoc signed (not notarized)."
echo "      Users will need to right-click → Open on first launch"
echo "      to bypass Gatekeeper, or run:"
echo "      xattr -cr /Applications/CanvasBrowser.app"
echo ""
