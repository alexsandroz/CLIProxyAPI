#!/usr/bin/env bash
#
# build.sh - Linux/macOS Build Script
#
# This script automates the process of building and running the Docker container
# with version information dynamically injected at build time.

set -euo pipefail

if [[ "${1:-}" != "" ]]; then
  echo "Error: unknown option '${1}'."
  echo "Usage: ./docker-build.sh"
  exit 1
fi

# --- Step 1: Choose Environment ---
echo "Please select an option:"
echo "1) Run using Pre-built Image (Recommended)"
echo "2) Build from Source and Run (For Developers)"
echo "3) Build and Save Image for Raspberry Pi (ARM64)"
read -r -p "Enter choice [1-3]: " choice

# --- Step 2: Execute based on choice ---
case "$choice" in
  1)
    echo "--- Running with Pre-built Image ---"
    docker compose up -d --remove-orphans --no-build
    echo "Services are starting from remote image."
    echo "Run 'docker compose logs -f' to see the logs."
    ;;
  2)
    echo "--- Building from Source and Running ---"

    # Get Version Information
    VERSION="$(git describe --tags --always --dirty)"
    COMMIT="$(git rev-parse --short HEAD)"
    BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    echo "Building with the following info:"
    echo "  Version: ${VERSION}"
    echo "  Commit: ${COMMIT}"
    echo "  Build Date: ${BUILD_DATE}"
    echo "----------------------------------------"

    # Build and start the services with a local-only image tag
    export CLI_PROXY_IMAGE="cli-proxy-api:local"

    # Check for docker-compose (v1) vs docker compose (v2)
    DOCKER_COMPOSE="docker compose"
    if ! docker compose version >/dev/null 2>&1; then
      if command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE="docker-compose"
      fi
    fi

    echo "Building the Docker image..."
    ${DOCKER_COMPOSE} build --build-arg VERSION="${VERSION}" --build-arg COMMIT="${COMMIT}" --build-arg BUILD_DATE="${BUILD_DATE}"

    echo "Starting the services..."
    ${DOCKER_COMPOSE} up -d --remove-orphans --pull never

    echo "Build complete. Services are starting."
    echo "Run 'docker compose logs -f' to see the logs."
    ;;
  3)
    echo "--- Building for Raspberry Pi (ARM64) ---"

    # Get Version Information
    VERSION="$(git describe --tags --always --dirty)"
    COMMIT="$(git rev-parse --short HEAD)"
    BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    IMAGE_NAME="cli-proxy-api:raspberry-pi"
    OUTPUT_FILE="cli-proxy-api-arm64.tar"

    echo "Building for ARM64 with the following info:"
    echo "  Version: ${VERSION}"
    echo "  Commit: ${COMMIT}"
    echo "  Build Date: ${BUILD_DATE}"
    echo "----------------------------------------"

    # Ensure buildx is available and used
    if ! docker buildx version >/dev/null 2>&1; then
      echo "Error: docker buildx is required for cross-platform builds."
      exit 1
    fi

    echo "Building the Docker image for linux/arm64..."
    docker buildx build --platform linux/arm64 \
      -t "${IMAGE_NAME}" \
      --build-arg VERSION="${VERSION}" \
      --build-arg COMMIT="${COMMIT}" \
      --build-arg BUILD_DATE="${BUILD_DATE}" \
      --load .

    echo "Saving the image to ${OUTPUT_FILE}..."
    docker save "${IMAGE_NAME}" > "${OUTPUT_FILE}"

    echo "----------------------------------------"
    echo "Build complete! File generated: ${OUTPUT_FILE}"
    echo "To install on Raspberry Pi:"
    echo "1. Transmit the file: scp ${OUTPUT_FILE} user@raspberry-ip:~/"
    echo "2. On Raspberry Pi, run: docker load < ${OUTPUT_FILE}"
    echo "3. Run the container: docker run -d --name cli-proxy -p 8080:8080 ${IMAGE_NAME}"
    ;;
  *)
    echo "Invalid choice. Please enter 1, 2 or 3."
    exit 1
    ;;
esac
