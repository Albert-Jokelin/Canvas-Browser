#!/bin/bash
set -e

APP_NAME="CanvasBrowser"
BUILD_DIR=".build/arm64-apple-macosx/debug"
APP_BUNDLE="$APP_NAME.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Parse arguments
RUN_TESTS=true
SKIP_LAUNCH=false
RELEASE_BUILD=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-tests) RUN_TESTS=false ;;
        --no-launch) SKIP_LAUNCH=true ;;
        --release) RELEASE_BUILD=true ;;
        -h|--help)
            echo "Usage: ./bundle_and_run.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-tests    Skip running tests before building"
            echo "  --no-launch     Build only, don't launch the app"
            echo "  --release       Build release configuration"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║       Canvas Browser Build Script      ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# Step 1: Run Tests
if [ "$RUN_TESTS" = true ]; then
    print_step "Running unit tests..."
    if swift test 2>&1 | tee /tmp/test_output.txt | grep -E "(passed|failed|error:)" ; then
        if grep -q "with 0 failures" /tmp/test_output.txt; then
            print_success "All tests passed!"
        else
            print_error "Some tests failed. Aborting build."
            exit 1
        fi
    else
        print_error "Test execution failed. Aborting build."
        exit 1
    fi
    echo ""
fi

# Step 2: Build
if [ "$RELEASE_BUILD" = true ]; then
    print_step "Building Canvas Browser (release)..."
    BUILD_DIR=".build/arm64-apple-macosx/release"
    swift build -c release
else
    print_step "Building Canvas Browser (debug)..."
    swift build
fi
print_success "Build completed!"
echo ""

# Step 3: Create App Bundle
print_step "Creating $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "CanvasBrowser/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

print_success "App bundle created!"
echo ""

# Step 4: Code Sign
print_step "Code signing..."
codesign --force --deep --sign - --entitlements "CanvasBrowser/Resources/Entitlements.entitlements" "$APP_BUNDLE"
print_success "Code signing complete!"
echo ""

# Step 5: Launch (unless skipped)
if [ "$SKIP_LAUNCH" = false ]; then
    print_step "Launching Canvas Browser..."
    echo "---------------------------------------------------"
    open "$APP_BUNDLE"
else
    print_success "Build complete! App bundle available at: $APP_BUNDLE"
fi
