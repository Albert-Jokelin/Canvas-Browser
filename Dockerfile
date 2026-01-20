# Canvas Browser - Release Build
# Uses prebuilt dependencies from Dockerfile.deps
ARG BASE_IMAGE=canvas-deps:latest
FROM ${BASE_IMAGE}

WORKDIR /app

# Copy source code
# Note: node_modules is excluded via .dockerignore, so the base image's modules are preserved
COPY . .

# Generate PNG icons
RUN mkdir -p assets/icons && \
    for size in 16 32 48 64 128 256 512; do \
      convert -background '#1a73e8' -size ${size}x${size} xc:'#1a73e8' \
        -fill white -gravity center -font DejaVu-Sans-Bold \
        -pointsize $((size * 6 / 10)) -annotate +0+$((size/10)) 'C' \
        assets/icons/${size}x${size}.png; \
    done && \
    cp assets/icons/256x256.png assets/icons/icon.png

# Build
RUN npm run build --linux

CMD ["echo", "Build complete!"]
