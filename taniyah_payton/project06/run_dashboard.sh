#!/usr/bin/env bash
# run_dashboard.sh
# Builds the BPD Homicide Analysis Dashboard and starts the container.
set -euo pipefail

IMAGE="bpd-homicide-dashboard"
CONTAINER="bpd-dashboard"
PORT=3838
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================================"
echo "  Baltimore City Police Department"
echo "  Homicide Analysis Dashboard"
echo "======================================================"
echo ""

# Stop & remove any previous container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "-> Removing existing container..."
  docker stop  "${CONTAINER}" > /dev/null 2>&1 || true
  docker rm    "${CONTAINER}" > /dev/null 2>&1 || true
fi

# Build
echo "-> Building Docker image (R packages cached after first build)..."
docker build -t "${IMAGE}" "${SCRIPT_DIR}"
echo "   Build complete."

# Run
echo "-> Starting container on port ${PORT}..."
docker run -d \
  --name "${CONTAINER}" \
  -p "${PORT}:3838" \
  --restart unless-stopped \
  "${IMAGE}"

# Wait for health check
echo "-> Waiting for Shiny Server to become ready..."
MAX_WAIT=120
ELAPSED=0
until docker inspect --format='{{.State.Health.Status}}' "${CONTAINER}" 2>/dev/null \
      | grep -q "healthy" || [ "${ELAPSED}" -ge "${MAX_WAIT}" ]; do
  sleep 5
  ELAPSED=$((ELAPSED + 5))
  printf "   %ds elapsed...\r" "${ELAPSED}"
done

echo ""
if [ "${ELAPSED}" -ge "${MAX_WAIT}" ]; then
  echo "Warning: health check timed out. App may still be loading."
  echo "Check: docker logs ${CONTAINER}"
fi

echo ""
echo "======================================================"
echo "  Dashboard ready!"
echo "  Open:  http://localhost:${PORT}"
echo ""
echo "  Stop:  docker stop ${CONTAINER}"
echo "  Logs:  docker logs -f ${CONTAINER}"
echo "======================================================"
