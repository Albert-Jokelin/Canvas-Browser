#!/bin/bash
# Optimized test runner
# 1. Builds test image (cached)
# 2. Runs tests in non-interactive mode
# 3. Mounts source for live updates (optional, but keeping it simple for speed)

echo "🏗️  Building test environment..."
sudo docker build -t canvas-test -f Dockerfile.test .

echo "🧪 Running tests..."
sudo docker run --rm canvas-test
