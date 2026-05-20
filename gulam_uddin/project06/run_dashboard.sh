#!/usr/bin/env bash
set -e

IMAGE_NAME="baltimore-homicide-dashboard"
CONTAINER_NAME="homicide-dashboard"
HOST_PORT=3838

echo "============================================================"
echo "  Baltimore City PD — Homicide Analysis Dashboard"
echo "============================================================"

# ── Stop any existing container ──────────────────────────────────
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "→ Stopping existing container '${CONTAINER_NAME}'..."
    docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    docker rm   "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

# ── Build image ──────────────────────────────────────────────────
echo ""
echo "→ Building Docker image '${IMAGE_NAME}'..."
echo "  (This may take several minutes the first time — R packages are being installed)"
echo ""

docker build \
    --tag "${IMAGE_NAME}:latest" \
    --file Dockerfile \
    . 2>&1 | while IFS= read -r line; do echo "   [build] $line"; done

echo ""
echo "→ Build complete."

# ── Run container ────────────────────────────────────────────────
echo "→ Starting dashboard container on port ${HOST_PORT}..."

docker run \
    --detach \
    --name  "${CONTAINER_NAME}" \
    --publish "${HOST_PORT}:3838" \
    --restart unless-stopped \
    "${IMAGE_NAME}:latest"

# ── Wait for Shiny to be ready ───────────────────────────────────
echo "→ Waiting for Shiny server to start..."
MAX_WAIT=60
WAITED=0
until curl -s -o /dev/null "http://localhost:${HOST_PORT}" || [ $WAITED -ge $MAX_WAIT ]; do
    sleep 2
    WAITED=$((WAITED + 2))
    echo "   ... still starting ($WAITED s)"
done

echo ""
echo "============================================================"
echo "  ✅  Dashboard is running!"
echo ""
echo "  Open your browser to:"
echo "      http://localhost:${HOST_PORT}"
echo ""
echo "  The app will scrape live Baltimore homicide data on first"
echo "  load (requires internet). A cache is saved for ~6 hours."
echo ""
echo "  To stop the dashboard:"
echo "      docker stop ${CONTAINER_NAME}"
echo "============================================================"
