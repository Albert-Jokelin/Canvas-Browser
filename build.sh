#!/bin/bash
# Build Canvas AppImage using Docker
# Run: ./build.sh

set -e

echo "🐳 Building Canvas Browser with Docker..."
echo ""

# Create release directory if it doesn't exist
mkdir -p release

# Build the Dependencies image
echo "📦 Updating Dependencies image (if needed)..."
sudo docker build -t canvas-deps -f Dockerfile.deps .

# Build the Release image
echo "🚀 Building Release image..."
sudo docker build -t canvas-builder .

# Run the container and extract the AppImage
echo ""
echo "🔨 Extracting AppImage..."
sudo docker run --rm -v "$(pwd)/release:/output" canvas-builder sh -c "cp -r /app/release/* /output/ 2>/dev/null || echo 'No files to copy'"

# Fix permissions
sudo chown -R $(whoami):$(whoami) release/ 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -la release/ 2>/dev/null || echo "Check release/ folder"
echo ""
echo "To run Canvas:"
echo "  chmod +x release/*.AppImage"
echo "  ./release/*.AppImage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
