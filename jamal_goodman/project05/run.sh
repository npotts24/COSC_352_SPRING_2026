
set -euo pipefail

IMAGE_NAME="baltimore-homicide-histogram-r"

echo "Building Docker image: ${IMAGE_NAME}"
docker build -t "${IMAGE_NAME}" .

echo "Running container..."
docker run --rm -v "$(pwd)":/app "${IMAGE_NAME}"